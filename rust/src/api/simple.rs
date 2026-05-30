use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Key, Nonce,
};

pub fn hardware_accelerated_encrypt(
    buffer: Vec<u8>,
    key_data: Vec<u8>,
    iv_data: Vec<u8>,
    chunk_position: u32,
) -> Vec<u8> {
    let key = Key::<Aes256Gcm>::from_slice(&key_data);
    let cipher = Aes256Gcm::new(key);

    let mut chunk_specific_iv = iv_data.clone();
    let position_bytes = chunk_position.to_le_bytes();

    let len = chunk_specific_iv.len();
    for i in 0..4 {
        chunk_specific_iv[len - 4 + i] ^= position_bytes[i];
    }

    let nonce = Nonce::from_slice(&chunk_specific_iv);
    
    cipher.encrypt(nonce, buffer.as_ref()).expect("Hardware encryption failed")
}