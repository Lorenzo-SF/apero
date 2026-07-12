defmodule Apero.Crypto.Cipher do
  @moduledoc """
  Symmetric encryption and streaming cipher utilities.

  Supports AES-256-GCM (authenticated), ChaCha20-Poly1305, and
  AES-256-CTR (streaming mode for large files/streams).

  All encrypted values are self-contained (IV/nonce + tag + ciphertext,
  Base64-encoded) and use `:crypto.strong_rand_bytes/1` for key/IV generation.
  """

  @aes_key_bytes 32
  @iv_bytes 12
  @tag_bytes 16

  # ═══════════════════════════════════════════════════════════════════════
  # AES-256-GCM (authenticated symmetric encryption)
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Encrypts plaintext with AES-256-GCM. Returns `{:ok, ciphertext}`."
  @spec encrypt(binary(), binary() | nil) :: {:ok, binary()}
  def encrypt(plaintext, key \\ nil) when is_binary(plaintext) do
    key = key || generate_key()
    iv = :crypto.strong_rand_bytes(@iv_bytes)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, "", true)
    result = Base.encode64(iv <> tag <> ciphertext)
    {:ok, result}
  end

  @doc "Decrypts a value encrypted with `encrypt/2`. Returns `{:ok, plaintext}` or `{:error, reason}`."
  @spec decrypt(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def decrypt(encoded, key) when is_binary(encoded) and is_binary(key) do
    with {:ok, decoded} <- Base.decode64(encoded),
         <<iv::binary-@iv_bytes, tag::binary-@tag_bytes, ciphertext::binary>> <- decoded do
      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        :error -> {:error, :decryption_failed}
      end
    else
      _ -> {:error, :invalid_format}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ChaCha20-Poly1305
  # ═══════════════════════════════════════════════════════════════════════

  @doc "Encrypts plaintext with ChaCha20-Poly1305."
  @spec encrypt_chacha20(binary(), binary()) :: binary()
  def encrypt_chacha20(plaintext, key) when is_binary(plaintext) and byte_size(key) == 32 do
    nonce = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:chacha20_poly1305, key, nonce, plaintext, "", true)

    Base.encode64(nonce <> tag <> ciphertext)
  end

  @doc "Decrypts ChaCha20-Poly1305 encrypted data."
  @spec decrypt_chacha20(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def decrypt_chacha20(encoded, key) when is_binary(encoded) and byte_size(key) == 32 do
    with {:ok, decoded} <- Base.decode64(encoded),
         <<nonce::binary-12, tag::binary-16, ciphertext::binary>> <- decoded do
      result =
        :crypto.crypto_one_time_aead(:chacha20_poly1305, key, nonce, ciphertext, "", tag, false)

      case result do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        :error -> {:error, :decryption_failed}
      end
    else
      _ -> {:error, :invalid_encoded_data}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # AES-256-CTR (streaming mode — for large files)
  # ═══════════════════════════════════════════════════════════════════════

  @dialyzer {:nowarn_function, stream_init: 1}
  @dialyzer {:nowarn_function, stream_encrypt: 2}
  @dialyzer {:nowarn_function, stream_finalize: 1}

  @doc "Starts an AES-256-CTR encryption stream. Use with `stream_encrypt/2` and `stream_finalize/1`."
  @spec stream_init(binary()) :: {any(), binary()}
  def stream_init(key) when byte_size(key) == 32 do
    iv = :crypto.strong_rand_bytes(16)
    state = :crypto.crypto_init(:aes_256_ctr, key, iv, true)
    {state, iv}
  end

  @doc "Encrypts a chunk of data in streaming mode."
  @spec stream_encrypt({any(), binary()}, binary()) :: {any(), binary(), binary()}
  def stream_encrypt({state, iv}, chunk) do
    ciphertext = :crypto.crypto_update(state, chunk)
    {state, iv, ciphertext}
  end

  @doc "Finalizes a streaming encryption. Returns the final state (discard after)."
  @spec stream_finalize(any()) :: binary()
  def stream_finalize(state) do
    :crypto.crypto_final(state)
  end

  @dialyzer {:nowarn_function, decrypt_ctr: 3}

  @doc "Decrypts data encrypted with AES-256-CTR streaming."
  @spec decrypt_ctr(binary(), binary(), binary()) :: {:ok, binary()} | :error
  def decrypt_ctr(ciphertext, key, iv) when byte_size(key) == 32 and byte_size(iv) == 16 do
    state = :crypto.crypto_init(:aes_256_ctr, key, iv, false)
    plaintext = :crypto.crypto_update(state, ciphertext)
    final = :crypto.crypto_final(state)
    {:ok, plaintext <> final}
  rescue
    _ -> :error
  end

  # ── Private ────────────────────────────────────────────────────────

  defp generate_key, do: :crypto.strong_rand_bytes(@aes_key_bytes)
end
