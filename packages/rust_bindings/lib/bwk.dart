library;

export 'src/rust/api/simple.dart'
    show
        SpNotification,
        SpNotification_ScanStarted,
        SpNotification_ScanReceiveProgress,
        SpNotification_ScanSpendProgress,
        SpNotification_ScanCompleted,
        SpNotification_ScanStopped,
        SpNotification_ScanFailed,
        SpNotification_NewOutput,
        SpNotification_OutputSpent,
        SpNotification_Broadcasted,
        SpNotification_BroadcastFailed,
        SpNotification_ElectrumTx,
        SpNotification_HeaderProgressStarted,
        SpNotification_HeaderProgress,
        SpNotification_HeaderProgressCompleted,
        SpNotification_HeaderProgressFailed,
        SpNotification_PaymentHistoryUpdated,
        SpNotification_ElectrumDisconnected,
        SpNotification_Reorg,
        SpNotification_HeaderCheckpointMismatch,
        SpNotification_ElectrumConnected,
        RecipientView,
        RecipientView_Sp,
        RecipientView_Standard,
        // The typed SP error and its variants: a consumer that cannot name the
        // variants is back to matching on message text.
        SpError,
        SpError_ScannerAlreadyRunning,
        SpError_DisposeTimedOut,
        SpError_SimulationDrifted,
        SpError_Other,
        // freezed copyWith mixin — consumers embed RecipientView as a field in
        // their own @freezed classes (e.g. bb-mobile SpState), whose generated
        // code references $RecipientViewCopyWith.
        $RecipientViewCopyWith;
export 'src/rust/third_party/dart_bwk/api/regtest.dart';
export 'src/rust/third_party/dart_bwk/api/sp_account.dart';
export 'src/rust/third_party/dart_bwk/api/types.dart';
