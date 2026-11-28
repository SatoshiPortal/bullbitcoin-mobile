package com.bullbitcoin.mobile

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import org.xmlpull.v1.XmlPullParser
import kotlin.math.max

/**
 * Draws its `android:src` bitmap the way Flutter draws a `BoxFit.cover` image:
 * scaled by `max(bounds width / bitmap width, bounds height / bitmap height)`,
 * centred on the bounds, with the overflow cropped instead of stretched.
 *
 * No XML drawable can express that geometry on the APIs this app supports: a
 * layer-list `<bitmap>` gravity fills at most one axis (`fill_vertical` scales a
 * square texture to the screen height but leaves it unconstrained by the width),
 * `center_crop` only exists on `BitmapDrawable` from API 31, and `fill`
 * distorts the texture. The platform's documented extension point for this is a
 * custom drawable inflated from XML:
 *
 *     <drawable
 *         class="com.bullbitcoin.mobile.CoverBitmapDrawable"
 *         android:src="@drawable/splash_camo" />
 *
 * The class is instantiated through its public no-argument constructor and then
 * given this override of [inflate], so both must stay public.
 */
class CoverBitmapDrawable : Drawable() {
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
    private var bitmap: Bitmap? = null

    override fun inflate(
        resources: Resources,
        parser: XmlPullParser,
        attrs: AttributeSet,
        theme: Resources.Theme?,
    ) {
        val styled = resources.obtainAttributes(attrs, intArrayOf(android.R.attr.src))
        val source = try {
            styled.getResourceId(0, 0)
        } finally {
            styled.recycle()
        }
        if (source == 0) return
        bitmap = BitmapFactory.decodeResource(resources, source)
        invalidateSelf()
    }

    override fun draw(canvas: Canvas) {
        val source = bitmap ?: return
        val area = bounds
        if (area.isEmpty || source.width <= 0 || source.height <= 0) return
        val scale = max(
            area.width().toFloat() / source.width,
            area.height().toFloat() / source.height,
        )
        val drawnWidth = source.width * scale
        val drawnHeight = source.height * scale
        val left = area.exactCenterX() - drawnWidth / 2f
        val top = area.exactCenterY() - drawnHeight / 2f
        val saved = canvas.save()
        canvas.clipRect(area)
        canvas.drawBitmap(
            source,
            null,
            RectF(left, top, left + drawnWidth, top + drawnHeight),
            paint,
        )
        canvas.restoreToCount(saved)
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
        invalidateSelf()
    }

    override fun getAlpha(): Int = paint.alpha

    // Drawable.getOpacity() is deprecated from API 35 but stays abstract.
    @Suppress("OVERRIDE_DEPRECATION")
    override fun getOpacity(): Int =
        if (paint.alpha == OPAQUE_ALPHA) PixelFormat.OPAQUE else PixelFormat.TRANSLUCENT

    override fun getIntrinsicWidth(): Int = bitmap?.width ?: -1

    override fun getIntrinsicHeight(): Int = bitmap?.height ?: -1
}

private const val OPAQUE_ALPHA = 0xFF
