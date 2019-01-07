# README

## Generating the keys

Generation of keys:

```
gpg --gen-key
```

Save the public key:

```
gpg --export --armor
```

Save the private key:

```
gpg --export-secret-key --armor
```

Save the trust for the keys:

```
gpg --export-ownertrust
```

Then:

- Keep the private key somewhere safe
- Store the public key and ownertrust in the `data` directory
