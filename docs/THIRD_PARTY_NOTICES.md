# Third party notices

MacWhispr is created by Hrithik Saini. Copyright © 2026 Hrithik Saini. All rights reserved. No license to redistribute or modify MacWhispr source is granted by the presence of a source repository.

## Speech engine

Release candidates bundle whisper.cpp v1.9.4, including its ggml backends, under the MIT license. The full upstream notice is in `licenses/whisper.cpp-MIT.txt`.

Source: https://github.com/ggml-org/whisper.cpp/tree/v1.9.4

The upstream CLI includes miniaudio (including its embedded dr_wav, dr_mp3 and dr_flac decoders) and stb_vorbis. Their permissive notices are retained in `licenses/Audio-decoders.txt`. The release build uses Apple system frameworks and embeds its Metal kernels. It does not redistribute Homebrew libraries.

## Whisper model files

Model files are downloaded separately from https://huggingface.co/ggerganov/whisper.cpp. They are not included in the app archive. OpenAI Whisper code and original model weights are MIT licensed; consult https://github.com/openai/whisper/blob/main/LICENSE and the chosen model repository for applicable terms. MacWhispr is an independent app and is not affiliated with OpenAI or the whisper.cpp maintainers.

## Website typeface

Manrope, designed by Mikhail Sharanda and contributors, is bundled locally under the SIL Open Font License 1.1. The full notice is in `licenses/Manrope-OFL.txt`.

Source: https://github.com/google/fonts/tree/main/ofl/manrope

The website does not load fonts, analytics, or scripts from third party services.
