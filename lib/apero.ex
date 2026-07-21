defmodule Apero do
  @moduledoc """
  Apero — Pure utility library for Elixir (no shell execution).

  Provides domain-specific tools organised into independent modules behind a
  consistent `{:ok, result} | {:error, reason}` interface.

  ## What's in Apero

  These modules are pure Elixir/Erlang with no shell execution dependency:

  ### Security
  - `Apero.Crypto` — hashing, AES encryption, key and password generation
  - `Apero.Crypto.Hash` — SHA-256, SHA-512, MD5, HMAC
  - `Apero.Crypto.Cipher` — AES-256-GCM, ChaCha20-Poly1305, AES-256-CTR streaming
  - `Apero.Crypto.Key` — PBKDF2, Argon2id, ECDH, RSA key generation
  - `Apero.Crypto.Random` — key generation, random hex/token/password, secure_compare

  ### Environment
  - `Apero.Env` — environment variable management and `.env` files
  - `Apero.Conf` — config file validation, linting and formatting

  ### Cache
  - `Apero.Cache` — unified cache interface with ETS adapter

  ### System (pure subset)
  - `Apero.OS` — OS type detection and hostname (pure Erlang)
  - `Apero.Proc` — command availability, VM introspection (pure Elixir)

  ### File & Path
  - `Apero.File` — file/path operations, atomic writes, temp resources, locking
  - `Apero.File.Path` — path operations (copy, move, delete, glob, etc.)
  - `Apero.File.IO` — I/O operations (atomic writes, checksums, temp resources, locking)
  - `Apero.File.Tree` — ASCII tree generation and printing
  - `Apero.File.Watcher` — file system watching via GenServer

  ### Retry
  - `Apero.Retry` — configurable retry with backoff

  ## What moved to Trebejo

  Shell-based modules moved to `Trebejo` v1.0.0:
  - `Trebejo.Docker`, `Trebejo.Git`, `Trebejo.SSH`, `Trebejo.Kubernetes`
  - `Trebejo.Compress`, `Trebejo.Network`, `Trebejo.File.IO` (run_cmd based)
  - `Trebejo.OS` (arch, kernel, memory, CPU — shell-based)
  - `Trebejo.Proc` (ps, kill, lsof, fuser, logs — shell-based)
  - `Trebejo.File` (watch/unwatch — depends on Arrea.WorkerSupervisor)
  """

  # Crypto
  @doc "Delegates to `Apero.Crypto.Cipher.encrypt/2`."
  defdelegate encrypt(plaintext, key), to: Apero.Crypto.Cipher

  @doc "Delegates to `Apero.Crypto.Cipher.decrypt/2`."
  defdelegate decrypt(encoded, key), to: Apero.Crypto.Cipher

  @doc "Delegates to `Apero.Crypto.Hash.sha256/1` (cached in ETS)."
  defdelegate sha256(data), to: Apero.Crypto.Hash

  @doc "Delegates to `Apero.Crypto.Hash.sha512/1`."
  defdelegate sha512(data), to: Apero.Crypto.Hash

  @doc "Delegates to `Apero.Crypto.Hash.md5/1`."
  defdelegate md5(data), to: Apero.Crypto.Hash

  # Env
  @doc "Delegates to `Apero.Env.get/2`."
  defdelegate get_env(key, default \\ nil), to: Apero.Env, as: :get

  @doc "Delegates to `Apero.Env.put/2`."
  defdelegate put_env(key, value), to: Apero.Env, as: :put

  # OS
  @doc "Delegates to `Apero.OS.type/0`."
  defdelegate os_type(), to: Apero.OS, as: :type

  # Retry
  @doc "Delegates to `Apero.Retry.with/2`."
  defdelegate retry(fun, opts \\ []), to: Apero.Retry, as: :with
end
