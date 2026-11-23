package com.bullbitcoin.backup_storage

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class BackupStoragePlugin : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var resolver: ContentResolver
    private lateinit var io: ExecutorService
    private val main = Handler(Looper.getMainLooper())
    private var binding: ActivityPluginBinding? = null
    private var picker: Picker? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        io = Executors.newSingleThreadExecutor()
        resolver = binding.applicationContext.contentResolver
        channel = MethodChannel(binding.binaryMessenger, "com.bullbitcoin.backup_storage/folder")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        finishPicker()?.result?.error("unavailable", null, null)
        io.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        finishPicker()?.result?.error("unavailable", null, null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> respond(result) { pick(result) }
            "inspect", "list", "create", "read", "delete", "release" ->
                io.execute { respond(result) { result.success(operate(call)) } }
            else -> result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        val activity = binding?.activity ?: throw FolderError("unavailable")
        if (picker != null) throw FolderError("unavailable")
        val request = nextRequest.getAndUpdate { if (it == 49999) 42000 else it + 1 }
        val timeout = Runnable {
            if (picker?.request == request) {
                finishPicker()?.result?.error("unavailable", null, null)
                activity.finishActivity(request)
            }
        }
        picker = Picker(request, result, timeout)
        try {
            activity.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                    accessFlags or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
                ),
                request,
            )
            main.postDelayed(timeout, 115_000)
        } catch (error: Exception) {
            finishPicker()
            throw error
        }
    }

    private fun finishPicker(): Picker? {
        val current = picker
        picker = null
        current?.let { main.removeCallbacks(it.timeout) }
        return current
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (picker?.request != requestCode) return false
        val current = finishPicker() ?: return false
        if (resultCode != Activity.RESULT_OK) {
            current.result.error("cancelled", null, null)
            return true
        }

        io.execute {
            respond(current.result) {
                val selection = data ?: throw FolderError("permissionRevoked")
                val tree = selection.data ?: throw FolderError("permissionRevoked")
                if ((selection.flags and accessFlags) != accessFlags) {
                    throw FolderError("permissionRevoked")
                }
                val existed = hasGrant(tree)
                resolver.takePersistableUriPermission(tree, accessFlags)
                try {
                    current.result.success(inspect(tree) + ("token" to tree.toString()))
                } catch (error: Exception) {
                    if (!existed) release(tree)
                    throw error
                }
            }
        }
        return true
    }

    private fun operate(call: MethodCall): Any? {
        val tree = Uri.parse(call.required<String>("token"))
        if (call.method == "release") {
            release(tree)
            return null
        }
        if (!hasGrant(tree)) throw FolderError("permissionRevoked")
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val name = verifyRoot(root)
        val accountId = "${tree.authority}:$rootId"
        if (call.method != "inspect" && call.required<String>("accountId") != accountId) {
            throw FolderError("permissionRevoked")
        }

        return when (call.method) {
            "inspect" -> mapOf("id" to accountId, "name" to name)
            "list" -> children(tree)
            "create" -> create(tree, root, call)
            "read" -> {
                val maxBytes = call.required<Number>("maxBytes").toLong()
                val target = child(tree, call.required("id"), maxBytes)
                read(target, maxBytes)
            }
            "delete" -> {
                val target = child(tree, call.required("id"))
                if (!DocumentsContract.deleteDocument(resolver, target)) {
                    throw FolderError("unavailable")
                }
                null
            }
            else -> throw FolderError("unexpected")
        }
    }

    private fun hasGrant(tree: Uri) = resolver.persistedUriPermissions.any {
        it.uri == tree && it.isReadPermission && it.isWritePermission
    }

    private fun release(tree: Uri) {
        val grant = resolver.persistedUriPermissions.firstOrNull { it.uri == tree } ?: return
        var flags = 0
        if (grant.isReadPermission) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (grant.isWritePermission) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        if (flags != 0) resolver.releasePersistableUriPermission(tree, flags)
    }

    private fun inspect(tree: Uri): Map<String, String> {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val entry = verifyRoot(root)
        return mapOf("id" to "${tree.authority}:$rootId", "name" to entry)
    }

    private fun verifyRoot(root: Uri): String {
        try {
            return resolver.query(
                root, arrayOf(Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE), null, null, null,
            )?.use {
                if (!it.moveToFirst() || it.getString(1) != Document.MIME_TYPE_DIR) {
                    throw FolderError("permissionRevoked")
                }
                it.getString(0)
            } ?: throw FolderError("unavailable")
        } catch (error: FileNotFoundException) {
            throw FolderError("permissionRevoked")
        } catch (error: IllegalArgumentException) {
            throw FolderError("permissionRevoked")
        }
    }

    private fun children(tree: Uri): List<Map<String, Any?>> {
        val parent = DocumentsContract.getTreeDocumentId(tree)
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
        return resolver.query(uri, columns, null, null, null)?.use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    if (cursor.getString(2) != Document.MIME_TYPE_DIR) {
                        add(
                            mapOf(
                                "id" to cursor.getString(0),
                                "name" to cursor.getString(1),
                                "size" to if (cursor.isNull(3)) null else cursor.getLong(3),
                                "modifiedMs" to if (cursor.isNull(4)) null else cursor.getLong(4),
                            ),
                        )
                    }
                }
            }
        } ?: throw FolderError("unavailable")
    }

    private fun child(tree: Uri, id: String, maxBytes: Long? = null): Uri {
        val entry = children(tree).firstOrNull { it["id"] == id } ?: throw FolderError("notFound")
        val size = entry["size"] as? Long
        if (maxBytes != null && size != null && size > maxBytes) throw FolderError("tooLarge")
        return DocumentsContract.buildDocumentUriUsingTree(tree, id)
    }

    private fun create(tree: Uri, root: Uri, call: MethodCall): Map<String, Any> {
        val name = call.required<String>("name")
        if (name.isEmpty() || name == "." || name == ".." || name.any { it == '/' || it == '\\' || it == '\u0000' }) {
            throw FolderError("unexpected")
        }
        val bytes = call.required<ByteArray>("bytes")
        val existing = children(tree)
        if (existing.any { it["name"] == name }) throw FolderError("unavailable")

        val target = DocumentsContract.createDocument(resolver, root, call.required("mimeType"), name)
            ?: throw FolderError("unavailable")
        val id = DocumentsContract.getDocumentId(target)
        if (existing.any { it["id"] == id }) throw FolderError("unavailable")
        try {
            val actualName = resolver.query(
                target, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null,
            )?.use { if (it.moveToFirst()) it.getString(0) else null }
            if (actualName != name) throw FolderError("unavailable")
            val stream = resolver.openOutputStream(target, "wt") ?: throw FolderError("unavailable")
            stream.use { it.write(bytes) }
        } catch (error: Exception) {
            try {
                DocumentsContract.deleteDocument(resolver, target)
            } catch (_: Exception) {
                // The caller can reconcile an ambiguous create by name.
            }
            throw error
        }
        return mapOf("id" to id, "name" to name, "size" to bytes.size)
    }

    private fun read(target: Uri, maxBytes: Long): ByteArray {
        if (maxBytes < 0) throw FolderError("tooLarge")
        val source = resolver.openInputStream(target) ?: throw FolderError("unavailable")
        return source.use {
            val output = ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            var total = 0L
            while (true) {
                val count = it.read(chunk, 0, (minOf(chunk.size - 1L, maxBytes - total) + 1).toInt())
                if (count == -1) break
                total += count
                if (total > maxBytes) throw FolderError("tooLarge")
                output.write(chunk, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun respond(result: MethodChannel.Result, operation: () -> Unit) {
        try {
            operation()
        } catch (error: Exception) {
            val cause = generateSequence<Throwable>(error) { it.cause?.takeUnless { cause -> cause === it } }
            val code = when {
                error is FolderError -> error.code
                cause.any {
                    it is ErrnoException && (it.errno == OsConstants.ENOSPC || it.errno == OsConstants.EDQUOT)
                } -> "quotaExceeded"
                error is SecurityException -> "permissionRevoked"
                error is FileNotFoundException -> "notFound"
                error is IOException -> "unavailable"
                else -> "unexpected"
            }
            result.error(code, null, null)
        }
    }

    private fun <T> MethodCall.required(key: String): T =
        argument<T>(key) ?: throw FolderError("unexpected")

    private class FolderError(val code: String) : Exception()
    private data class Picker(val request: Int, val result: MethodChannel.Result, val timeout: Runnable)

    companion object {
        private val nextRequest = AtomicInteger(42000)
        private const val accessFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        private val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED,
        )
    }
}
