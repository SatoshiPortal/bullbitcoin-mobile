use boltz_client::error::Error;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BoltzError {
    pub kind: String,
    pub message: String,
}

impl BoltzError {
    pub fn new(kind: String, message: String) -> Self {
        BoltzError { kind, message }
    }

    pub fn detail(&self) -> &str {
        &self.message
    }
}

impl From<Error> for BoltzError {
    fn from(value: Error) -> Self {
        BoltzError {
            kind: value.name(),
            message: value.message(),
        }
    }
}
