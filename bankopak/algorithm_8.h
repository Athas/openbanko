#ifndef ALGORITHM_8_H
#define ALGORITHM_8_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include "bankopladeformat/bankopladeformat.h"
#include "bitio.h"

typedef struct _rust_encoder rust_encoder;
rust_encoder *rust_encoder_init();
void rust_encoder_free(rust_encoder*);
bool rust_encoder_run(const rust_encoder*, const struct board*, uint64_t*);

typedef struct _rust_decoder rust_decoder;
rust_decoder *rust_decoder_init();
void rust_decoder_free(rust_decoder*);
bool rust_decoder_run(const rust_decoder*, uint64_t, struct board*);

void a8_compress(FILE *out, FILE *in) {
  struct board board;
  uint64_t idx;
  struct banko_reader reader;

  rust_encoder* encoder = rust_encoder_init();

  banko_reader_open(&reader, in);
  while (banko_reader_board(&reader, &board) == 0) {
    rust_encoder_run(encoder, &board, &idx);

    for (int i = 61; i >= 0; i--) {
      write_bit((idx >> i) & 1, out);
    }
  }
  flush_bit(out);
  banko_reader_close(&reader);
}

void a8_decompress(FILE *out, FILE *in) {
  struct board board;
  uint64_t idx;
  struct banko_writer writer;
  banko_writer_open(&writer, out);

  rust_decoder* decoder = rust_decoder_init();

  while (peek_bit(in) != EOF) {
    idx = 0;
    for (int i = 61; i >= 0; i--) {
      idx = (idx << 1) | read_bit(in);
    }

    rust_decoder_run(decoder, idx, &board);
    banko_writer_board(&writer, &board);
  }

  banko_writer_close(&writer);
}

#endif
