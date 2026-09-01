# meow-sampler / audio experiments

Scripts:

| Script | Faz |
|---|---|
| `synth_meow.py` | miado/tom sintético de frequência conhecida (teste) |
| `render_meows.py` | 1 miado → 25 amostras cromáticas (pitch-shift) + demos |
| `verify_pitch.py` | detecta o pitch real de uma pasta de samples e checa transposição vs. o nome do arquivo |
| `prep_instrument.py` | pasta de samples de instrumento → WAV mono normalizado, duração alvo, nomes canônicos (`out/<name>/<name>_<nota>.wav`) |
| `make_demo.py` | monta intervalos/acordes/escala/cadência de qualquer set (`--prefix`, `--samples`, `--root`) |

Exemplos:

```bash
# verificar transposição de um set de instrumento
python verify_pitch.py "/caminho/AltoSax.NoVib.ff.stereo"

# preparar o sax e ouvir os exercícios com timbre real
python prep_instrument.py "/caminho/AltoSax.NoVib.ff.stereo" --name sax --dur 2.5
python make_demo.py --samples out/sax --prefix sax_ --root c4 --out out/demos_sax
```

---

## meow-sampler (a demonstração do gato)

Transforma **um** miado de gato num conjunto cromático de amostras afinadas e monta
demos de intervalos / acordes / escala. É a "demonstração do gato" — o mascote do
CatEar cantando teoria musical.

**Não é o spike 3.1** (detecção de pitch). Isto é playback de amostra pré-renderizada,
risco ~zero. Fica isolado aqui, fora do fluxo do BMad.

> Decisão de produto em aberto: o miado com pitch-shift provavelmente entra só nos
> momentos do mascote (demonstrar, explicar, celebrar), não como timbre dos
> exercícios-núcleo — esses seguem com instrumento real (FR-2 / NFR-1). Ver
> `_bmad-output/planning-artifacts/prds/.../prd.md` se quiser formalizar.

## Passo a passo

```bash
cd experiments/meow-sampler
python3 -m venv .venv          # se falhar: sudo apt install python3-venv python3-full
source .venv/bin/activate      # daqui pra frente 'python' e 'pip' funcionam
pip install -r requirements.txt
sudo apt install rubberband-cli   # recomendado (ou: brew install rubberband)
```

> `librosa` foi removido — não tem wheel para Python 3.14. Só `numpy` + `soundfile`
> + o binário `rubberband`. O detector de pitch é numpy puro (autocorrelação).

1. **Consiga um miado.** Duas opções:

   - **Real:** [Kitty Meow — Npeo, freesound.org](https://freesound.org/people/Npeo/sounds/203121/)
     — CC-BY (credite "Npeo"). Baixe a **qualidade original** (precisa de conta grátis),
     não o preview MP3. Salve como `kitty_meow.wav` aqui na pasta.
   - **Sintético, para testar a pipeline agora sem baixar nada:**
     `python synth_meow.py` gera `synth_meow.wav`. Use esse arquivo nos passos abaixo.
     (Também serve como sinal de teste de frequência conhecida para o spike 3.1.)

2. **Gere as 25 amostras** (2 oitavas centradas no pitch natural do miado):

   ```bash
   python render_meows.py kitty_meow.wav
   ```

   O script detecta o pitch base, recorta sozinho o trecho mais estável, e escreve
   `out/meow/meow_<nota>.wav`. Ajustes:

   ```bash
   python render_meows.py kitty_meow.wav --low c3 --high c5    # range fixo
   python render_meows.py kitty_meow.wav --start 0.4 --end 1.1 # trecho manual
   ```

   **Notas mais longas** (mais fáceis de reconhecer) — estica sem mudar o pitch:

   ```bash
   python render_meows.py kitty_meow.wav --dur 2.5     # cada nota com 2,5 s
   ```

   Use `--dur 2.5` para intervalos e acordes isolados; para escalas, `--dur 1.2`
   lê melhor (senão a escala fica com 20 s+). Precisa do `rubberband`.

   > A demo `cadencia_resolucao` usa até `root + 14` (uma 9ª). Para `--root c4`,
   > gere pelo menos até `e5`:  `python render_meows.py <miado> --low c3 --high e5`.
   > `render_meows.py` apaga o range anterior antes de gerar.

3. **Monte e ouça as demos:**

   ```bash
   python make_demo.py --root c4
   # out/demos/demo_intervalo_terca_maior.wav, demo_acorde_maior.wav, demo_escala_maior.wav,
   # demo_acorde_maior_arpejo.wav, demo_cadencia_resolucao.wav, ...
   ```

   Abra os `.wav` em qualquer player. Se o `--root` cair fora do range gerado, o
   script avisa qual nota falta.

## O que esperar

- Perto do pitch natural do miado: soa bem, reconhecível como "gato".
- A ±12 semitons: começa a ficar "chipmunk" (agudo) ou "monstro" (grave). Com
  `rubberband` instalado, bem menos.
- Miado é **glissando** — o script pega o trecho mais estável, mas ainda vai ter
  um resíduo de deslize. Para demonstração está ótimo; se quiser cristalino,
  grave/edite um miado bem sustentado.

## Depois — tocar no Flutter

As amostras vão pra `assets/audio/meow/` no app. Sketch com `just_audio` (já na stack):

```dart
import 'package:just_audio/just_audio.dart';

Future<void> playSequence(List<String> notes,
    {Duration gap = const Duration(milliseconds: 350)}) async {
  for (final n in notes) {
    final p = AudioPlayer();
    await p.setAsset('assets/audio/meow/meow_$n.wav');
    await p.play();
    await Future.delayed(gap);
    await p.dispose();
  }
}

Future<void> playChord(List<String> notes) async {
  final players = [
    for (final n in notes) AudioPlayer()..setAsset('assets/audio/meow/meow_$n.wav')
  ];
  await Future.wait(players.map((p) => p.play()));
  await Future.delayed(const Duration(seconds: 2));
  for (final p in players) await p.dispose();
}

// terça maior:  playSequence(['c4', 'e4']);
// acorde maior: playChord(['c4', 'e4', 'g4']);
```
