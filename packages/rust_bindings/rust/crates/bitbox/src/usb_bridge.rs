/*
 * USB Bridge for BitBox02 Communication
 * 
 * This module provides a bridge between Rust and Kotlin for USB communication.
 * It uses in-memory storage to coordinate between the Rust side and Dart coordinator.
 */

use anyhow::Result;
use flutter_rust_bridge::frb;
use std::sync::{Arc, Mutex};
use std::collections::{HashMap, VecDeque};

type UsbWriteQueues = Arc<Mutex<HashMap<String, VecDeque<Vec<u8>>>>>;
type UsbReadQueues = Arc<Mutex<HashMap<String, VecDeque<Vec<u8>>>>>;

lazy_static::lazy_static! {
    pub static ref USB_WRITE_DATA: UsbWriteQueues = Arc::new(Mutex::new(HashMap::new()));
    pub static ref USB_READ_DATA: UsbReadQueues = Arc::new(Mutex::new(HashMap::new()));
}

pub struct PlatformUsbBridge {
    pub device_name: String,
}

impl PlatformUsbBridge {
    pub fn new(device_name: String) -> Self {
        Self { device_name }
    }
}

use async_trait::async_trait;
use bitbox_api::communication::{Error as CommError, ReadWrite};
use bitbox_api::Threading;

impl Threading for PlatformUsbBridge {}

#[async_trait]
impl ReadWrite for PlatformUsbBridge {
    fn write(&self, msg: &[u8]) -> Result<usize, CommError> {
        let write_data = USB_WRITE_DATA.clone();
        let mut data_guard = write_data.lock().unwrap();
        let queue = data_guard.entry(self.device_name.clone()).or_insert_with(VecDeque::new);
        queue.push_back(msg.to_vec());
        
        Ok(msg.len())
    }

    async fn read(&self) -> Result<Vec<u8>, CommError> {
        let read_data = USB_READ_DATA.clone();
        
        for _ in 0..600 { // 60 seconds timeout (600 * 100ms)
            {
                let mut data_guard = read_data.lock().unwrap();
                if let Some(queue) = data_guard.get_mut(&self.device_name) {
                    if let Some(data) = queue.pop_front() {
                        return Ok(data);
                    }
                }
            }
            
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
        }
        
        Err(CommError::Read)
    }
}

#[frb(sync)]
pub fn get_usb_write_data(serial_number: String) -> Option<Vec<u8>> {
    let write_data = USB_WRITE_DATA.clone();
    let mut data_guard = write_data.lock().unwrap();
    if let Some(queue) = data_guard.get_mut(&serial_number) {
        return queue.pop_front();
    }
    None
}

#[frb(sync)]
pub fn set_usb_read_data(serial_number: String, data: Vec<u8>) -> Result<()> {
    let read_data = USB_READ_DATA.clone();
    let mut data_guard = read_data.lock().unwrap();
    let queue = data_guard.entry(serial_number).or_insert_with(VecDeque::new);
    queue.push_back(data);
    Ok(())
}

pub async fn close_device(serial_number: &str) {
    {
        let write_data = USB_WRITE_DATA.clone();
        let mut data_guard = write_data.lock().unwrap();
        data_guard.remove(serial_number);
    }
    {
        let read_data = USB_READ_DATA.clone();
        let mut data_guard = read_data.lock().unwrap();
        data_guard.remove(serial_number);
    }
}