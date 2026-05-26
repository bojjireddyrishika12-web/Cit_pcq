# 8-bit Parallel ECC Protection Core

An automated parallel 8-input to 8-output secure Hamming error-correcting system designed to protect real-time wireless data packets.

## ⚙️ How It Works
* **True Parallel Processing:** Captures a full 8-bit data vector simultaneously in parallel using `ui_in[7:0]` on the rising edge of the clock.
* **Matrix Evaluation:** Processes the data block through a combinational hardware matrix core to evaluate parity verification conditions.
* **Self-Healing:** Instantly self-corrects single-bit data corruptions within a single clock cycle.
* **Status Flags:** Outputs the restored parallel word across `uo_out[7:0]` while pulsing the alert flag `uio_out[0]` high if an automated fix was applied.

## 🛠️ Pinout Mapping
* `ui_in[7:0]`: Raw incoming parallel data packet.
* `uo_out[7:0]`: Verified, clean parallel output data packet.
* `uio_out[0]`: Error detected alert flag (High = bit-flip was intercepted and fixed).
* `uio_out[1]`: Output data ready indicator.
