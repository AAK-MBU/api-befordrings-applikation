import hashlib
import secrets


api_key = secrets.token_urlsafe(32)
api_key_hash = hashlib.sha256(api_key.encode("utf-8")).hexdigest()

print()
print("RAW API KEY - give this to the client:")
print(api_key)

print()
print("HASH - store this in your .env/server config:")
print(api_key_hash)
