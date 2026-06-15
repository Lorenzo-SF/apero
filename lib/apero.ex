defmodule Apero do
  @moduledoc """
  Apero — Utility library for system operations and development workflows.

  Provides domain-specific tools organised into independent modules behind a
  consistent `{:ok, result} | {:error, reason}` interface.

  ## File & Path

  - `Apero.File` — file operations, path utilities, atomic writes, temp resources, locking, watching
  - `Apero.Compress` — zip, tar and gzip compression

  ## Git & VCS

  - `Apero.Git` / `Apero.Git.Local` — repository management, sync, commits

  ## Containers

  - `Apero.Docker` — Docker / Podman lifecycle management

  ## Security

  - `Apero.Crypto` — hashing, AES encryption, key and password generation
  - `Apero.Crypto.Hash` — SHA-256, SHA-512, MD5, HMAC
  - `Apero.Crypto.Cipher` — AES-256-GCM, ChaCha20-Poly1305, AES-256-CTR streaming
  - `Apero.Crypto.Key` — PBKDF2, Argon2id, ECDH, RSA key generation
  - `Apero.Crypto.Random` — key generation, random hex/token/password, secure_compare

  ## Environment

  - `Apero.Env` — environment variable management and `.env` files
  - `Apero.Conf` — config file validation, linting and formatting

  ## System

  - `Apero.OS` — operating system information (type, arch, CPU, memory, disk)
  - `Apero.Proc` — process and executable utilities

  ## Cache

  - `Apero.Cache` — unified cache interface with ETS adapter
  """
end
