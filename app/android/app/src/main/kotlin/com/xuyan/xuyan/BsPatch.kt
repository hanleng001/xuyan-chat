package com.xuyan.xuyan

import android.util.Log
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream
import java.io.*

/**
 * Pure Kotlin bspatch implementation.
 * Follows the official bspatch.c algorithm exactly.
 *
 * KEY: bsdiff uses sign-magnitude encoding for control values (offtin/offtout),
 * NOT two's complement. This is the most common implementation bug.
 */
object BsPatch {
    private const val TAG = "BsPatch"

    fun applyPatch(oldFile: File, patchFile: File, newFile: File): Boolean {
        try {
            val patchData = patchFile.readBytes()
            val oldData = oldFile.readBytes()

            // === Read header (32 bytes) ===
            if (patchData.size < 32) {
                Log.e(TAG, "Patch too small: ${patchData.size}")
                return false
            }

            val magic = String(patchData, 0, 8, Charsets.US_ASCII)
            if (magic != "BSDIFF40") {
                Log.e(TAG, "Invalid magic: $magic")
                return false
            }

            // Header values use bsdiff's sign-magnitude encoding (offtin)
            val ctrlLen = offtin(patchData, 8)
            val diffLen = offtin(patchData, 16)
            val newSize = offtin(patchData, 24)

            if (ctrlLen < 0 || diffLen < 0 || newSize < 0) {
                Log.e(TAG, "Invalid header: ctrlLen=$ctrlLen diffLen=$diffLen newSize=$newSize")
                return false
            }

            Log.d(TAG, "Patch: ctrlLen=$ctrlLen diffLen=$diffLen newSize=$newSize oldSize=${oldData.size}")

            // === Decompress blocks ===
            val patchStream = ByteArrayInputStream(patchData, 32, patchData.size - 32)
            val ctrlBlock = decompressBzip2(patchStream, ctrlLen.toInt())
            val diffBlock = decompressBzip2(patchStream, diffLen.toInt())
            val extraBlock = decompressBzip2(patchStream, patchData.size - 32 - ctrlLen.toInt() - diffLen.toInt())

            Log.d(TAG, "Decompressed: ctrl=${ctrlBlock.size} diff=${diffBlock.size} extra=${extraBlock.size}")

            // === Apply patch (following official bspatch.c exactly) ===
            val newData = ByteArray(newSize.toInt())
            var oldPos = 0
            var newPos = 0
            var diffPos = 0
            var extraPos = 0
            var ctrlPos = 0

            while (newPos < newSize) {
                // Read control tuple (3 x offtin = sign-magnitude int64)
                val dblen = offtin(ctrlBlock, ctrlPos); ctrlPos += 8
                val eblen = offtin(ctrlBlock, ctrlPos); ctrlPos += 8
                val adjust = offtin(ctrlBlock, ctrlPos); ctrlPos += 8

                // Sanity check
                if (newPos + dblen > newSize) {
                    Log.e(TAG, "dblen overflow: newPos=$newPos dblen=$dblen newSize=$newSize")
                    return false
                }

                // Step 1: Read diff bytes into newData, then add old data
                for (i in 0 until dblen.toInt()) {
                    // Read diff byte (signed, add to new)
                    val db = if (diffPos < diffBlock.size) diffBlock[diffPos++].toInt() else 0
                    newData[newPos + i] = db.toByte()
                }
                for (i in 0 until dblen.toInt()) {
                    if (oldPos + i >= 0 && oldPos + i < oldData.size) {
                        // Add old byte (unsigned) to new byte
                        newData[newPos + i] =
                            ((newData[newPos + i].toInt() and 0xFF) + (oldData[oldPos + i].toInt() and 0xFF) and 0xFF).toByte()
                    }
                }
                newPos += dblen.toInt()
                oldPos += dblen.toInt()

                // Sanity check
                if (newPos + eblen > newSize) {
                    Log.e(TAG, "eblen overflow: newPos=$newPos eblen=$eblen newSize=$newSize")
                    return false
                }

                // Step 2: Read extra bytes into newData
                for (i in 0 until eblen.toInt()) {
                    if (extraPos < extraBlock.size) {
                        newData[newPos + i] = extraBlock[extraPos++]
                    }
                }
                newPos += eblen.toInt()

                // Step 3: Adjust old position (signed)
                oldPos += adjust.toInt()
            }

            // Write result
            newFile.writeBytes(newData)
            Log.d(TAG, "Patch applied OK: ${newData.size} bytes")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Patch failed", e)
            return false
        }
    }

    /**
     * bsdiff's offtin: sign-magnitude int64, NOT two's complement.
     * Byte 7 bit 7 is the sign bit. Bytes 0-6 + byte 7 bits 0-6 are the magnitude (LE).
     * This matches the official bsdiff/bspatch C implementation.
     */
    private fun offtin(buf: ByteArray, offset: Int): Long {
        var y: Long = (buf[offset + 7].toLong() and 0x7F)  // High byte without sign
        y = y * 256 + (buf[offset + 6].toLong() and 0xFF)
        y = y * 256 + (buf[offset + 5].toLong() and 0xFF)
        y = y * 256 + (buf[offset + 4].toLong() and 0xFF)
        y = y * 256 + (buf[offset + 3].toLong() and 0xFF)
        y = y * 256 + (buf[offset + 2].toLong() and 0xFF)
        y = y * 256 + (buf[offset + 1].toLong() and 0xFF)
        y = y * 256 + (buf[offset].toLong() and 0xFF)
        if ((buf[offset + 7].toInt() and 0x80) != 0) y = -y
        return y
    }

    /**
     * Read exactly `compressedLen` bytes from the stream, then decompress with bzip2.
     * After decompression, the stream is positioned right after the compressed block.
     */
    private fun decompressBzip2(stream: ByteArrayInputStream, compressedLen: Int): ByteArray {
        val compressed = ByteArray(compressedLen)
        var totalRead = 0
        while (totalRead < compressedLen) {
            val read = stream.read(compressed, totalRead, compressedLen - totalRead)
            if (read == -1) break
            totalRead += read
        }
        if (totalRead != compressedLen) {
            Log.w(TAG, "decompressBzip2: expected $compressedLen bytes, got $totalRead")
        }
        val bzipIn = BZip2CompressorInputStream(ByteArrayInputStream(compressed, 0, totalRead))
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var n: Int
        while (bzipIn.read(buffer).also { n = it } > 0) {
            output.write(buffer, 0, n)
        }
        bzipIn.close()
        return output.toByteArray()
    }
}
