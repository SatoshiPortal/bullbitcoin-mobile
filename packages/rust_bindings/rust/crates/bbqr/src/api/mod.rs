use bbqr::continuous_join::{ContinuousJoinResult, ContinuousJoiner};
use bbqr::file_type::FileType;
use bbqr::join::Joined;
use bbqr::split::{Split, SplitOptions};
use extend::ext;

/// J. Azad  please create a custom error enum if needed instead of String.
#[ext]
pub impl Split {
    fn frb_override_try_from_data(
        bytes: &[u8],
        file_type: FileType,
        options: SplitOptions,
    ) -> Result<Split, String> {
        bbqr::split::Split::try_from_data(bytes, file_type, options).map_err(|e| format!("{:?}", e))
    }
}
#[ext]
pub impl ContinuousJoiner {
    fn frb_override_add_part(&mut self, part: String) -> Result<ContinuousJoinResult, String> {
        self.add_part(part).map_err(|e| format!("{:?}", e))
    }
}

#[ext]
pub impl Joined {
    fn frb_override_try_from_parts(parts: Vec<String>) -> Result<Joined, String> {
        Joined::try_from_parts(parts).map_err(|e| format!("{:?}", e))
    }
}
