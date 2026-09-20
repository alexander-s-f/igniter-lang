-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x4_effect_in_block_let
-- NEGATIVE (effect admission): direct host IO as the EXPRESSION of a block let inside a HOF lambda (read_in_map_lambda shape). Must refuse OOF-EC6.
module R14.X4

observed contract O {
  capability io_read: IO.Capability
  effect read_file using io_read
  input paths: Collection[String]

  compute contents = map(paths, (p) -> {
      let p = stdlib.IO.read_text(p, io_read)
      p
    })

  output contents: Collection[Result[String, IoError]]
}
