// Compatibility export; all Electrum failures share one sealed root.
export 'electrum_failure.dart'
    show
        ElectrumServersFailure,
        ElectrumServersLoadFailure,
        ElectrumServersSavePriorityFailure,
        ElectrumServersAddFailure,
        ElectrumServersDeleteFailure,
        ElectrumServersAlreadyExistsFailure,
        ElectrumServersUnreachableFailure,
        ElectrumServersExternalTorProxyUnavailableFailure,
        ElectrumServersUnexpectedFailure,
        AdvancedOptionsFailure,
        AdvancedOptionsInvalidStopGapFailure,
        AdvancedOptionsInvalidTimeoutFailure,
        AdvancedOptionsInvalidRetryFailure,
        AdvancedOptionsSaveFailure,
        AdvancedOptionsUnexpectedFailure;
