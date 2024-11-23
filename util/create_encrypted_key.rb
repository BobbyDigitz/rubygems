/encrypted_private_key.pem"

File.open encrypted_key_path, "w" do |io|
  io.write key.to_pem cipher, "Foo bar"
end
