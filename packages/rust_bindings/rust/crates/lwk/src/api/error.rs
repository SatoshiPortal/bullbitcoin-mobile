use lwk_wollet::elements::encode::Error as EncodeError;
use lwk_wollet::elements::pset::ParseError;
use std::sync::{MutexGuard, PoisonError};
// use lwk_wollet::elements::pset::ParseError;

// use std::string::ParseError;

/// Possible errors emitted
#[derive(Debug)]
pub struct LwkError {
    pub msg: String,
}

impl From<anyhow::Error> for LwkError {
    fn from(value: anyhow::Error) -> Self {
        LwkError {
            msg: value.to_string(),
        }
    }
}

impl From<lwk_wollet::Error> for LwkError {
    fn from(value: lwk_wollet::Error) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<EncodeError> for LwkError {
    fn from(value: EncodeError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

// impl From<PoisonError<MutexGuard<'_, lwk_wollet::Wollet>>> for LwkError {
//     fn from(value: lwk_wollet::Error) -> Self {
//         LwkError{
//             msg: format!("{:?}", value),
//         }
//     }
// }

impl From<ParseError> for LwkError {
    fn from(value: ParseError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_wollet::elements::pset::Error> for LwkError {
    fn from(value: lwk_wollet::elements::pset::Error) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_wollet::elements::bitcoin::transaction::ParseOutPointError> for LwkError {
    fn from(value: lwk_wollet::elements::bitcoin::transaction::ParseOutPointError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_wollet::elements::hex::DecodeFixedLengthBytesError> for LwkError {
    fn from(value: lwk_wollet::elements::hex::DecodeFixedLengthBytesError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_wollet::elements::AddressError> for LwkError {
    fn from(value: lwk_wollet::elements::AddressError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_signer::bip39::Error> for LwkError {
    fn from(value: lwk_signer::bip39::Error) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_signer::NewError> for LwkError {
    fn from(value: lwk_signer::NewError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<lwk_signer::SignError> for LwkError {
    fn from(value: lwk_signer::SignError) -> Self {
        LwkError {
            msg: format!("{:?}", value),
        }
    }
}

impl From<String> for LwkError {
    fn from(msg: String) -> Self {
        LwkError { msg }
    }
}

impl<T> From<PoisonError<MutexGuard<'_, T>>> for LwkError {
    fn from(e: PoisonError<MutexGuard<'_, T>>) -> Self {
        LwkError { msg: e.to_string() }
    }
}
