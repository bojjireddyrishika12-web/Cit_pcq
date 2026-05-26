## How it works

Accepts a full 8-bit parallel packet across ui_in, serializes it internally down an execution shift-pipeline, permutes it through crypto primitives, and drops the 8-bit result onto uo_out in parallel.

## How to test

Apply an 8-bit parallel byte onto ui_in, cycle the system clock to load and compute, and monitor uo_out for the resulting parallel ciphertext output vector.
