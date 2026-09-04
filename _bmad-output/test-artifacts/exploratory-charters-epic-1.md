---
type: exploratory-charters
scope: Epic 1 — Stories 1.1 a 1.4 (+ AudioSession da PR #17)
date: 2026-09-04
author: Murat (TEA)
method: session-based test management (SBTM)
---

# Charters de teste exploratório — CatEar, estado de 2026-09-04

## O que já é explorável

O app tem um caminho completo de ponta a ponta desde a Story 1.4:

boot → gate do banco → Home (4 abas) → **Praticar** → 23 exercícios de intervalo
com áudio real (13 specs distintos) → responder → feedback → avançar → fim do
loop. Mais Settings (tema claro/escuro/sistema) e os placeholders de Progresso e
Skill tree.

Não é um protótipo: é a `main()` real, com o `_JustAudioService` real, o catálogo
real e as 14 amostras reais.

## Por que exploratório agora, e não mais automação

O que a suíte atual cobre (222 unitários + 18 e2e) é **comportamento verificável
por asserção**: o arquivo existe, a chamada completa, o widget aparece, o erro é
do tipo certo. O que ela estruturalmente **não** cobre:

- **Ninguém nunca ouviu o app.** Toda verificação de áudio é programática. O job
  `e2e-android` roda o emulador com `-noaudio`, e os testes asseguram que
  `playSample` completa — não que o resultado soa como música. Um motif com click
  na interrupção, uma amostra fora de nível, um flourish atropelado: tudo isso
  passa verde.
- **Nada roda fora do emulador headless.** Latência real de áudio, fone
  bluetooth, alto-falante do aparelho, interrupção por chamada.
- **Não há nenhum tratamento de ciclo de vida.** `grep -rn "AppLifecycleState\|
  WidgetsBindingObserver" lib/` não retorna nada. O que acontece com um motif em
  andamento quando o app vai para background é comportamento não especificado e
  não testado.
- **Sessão longa nunca aconteceu.** O e2e responde 1 ou 2 exercícios; o loop tem
  23.

Exploratório é a ferramenta certa exatamente para essas classes.

## Charters

Ordenados por valor. Cada um é uma sessão cronometrada, com missão declarada.

### C1 — Ouvir o app (90 min, aparelho Android físico + fone)

**Missão:** percorrer o loop de prática inteiro, uma vez, prestando atenção só no
som. Não caçar bug de UI.

> **🚫 Não execute este charter no emulador.** Tentativa de 2026-09-04 gerou um
> **falso positivo**: um chiado atribuído às amostras que o A/B provou ser da
> cadeia de reprodução do emulador (Android reamostra → ponte do emulador →
> PipeWire reamostra para 192 kHz). Julgamento sonoro através do emulador é
> suspeito nos dois sentidos — inventa defeito e mascara defeito. Aparelho físico
> com fone, sem exceção.

Perguntas a responder:
- O motif `r0 → r1 → r0` (gaps de 450/450/900 ms) soa como uma frase musical ou
  como três notas soltas?
- A interrupção entre notas produz *click* ou *pop*? `playSample` corta a amostra
  anterior no meio — o corte é limpo?
- As 14 amostras têm loudness percebido igual? Foram normalizadas por EBU R128,
  mas nunca foram ouvidas em sequência. Notas agudas soam mais altas?
- Os intervalos **descendentes** soam corretos? O catálogo ordena os refs por
  `direction`; a percepção confirma?
- O flourish de acerto (`c4-e4-g4` a 170 ms) soa como celebração ou atropelo?
- A nota final segura por 900 ms e é cortada por `stop()` — o fade é abrupto?

**Por que é o C1:** é o único charter que nenhuma automação futura substitui, e
é a experiência central do produto. Um app de treino auditivo que soa mal está
quebrado mesmo com 222 testes verdes.

### C2 — Ciclo de vida e interrupções (45 min, aparelho físico)

**Missão:** interromper o app em todos os momentos ruins e ver o que sobra.

- Mandar para background **no meio de um motif**. Voltar. O áudio continua? Para?
  Rebobina? A tela ainda aceita resposta?
- Bloquear a tela durante a reprodução.
- Receber uma chamada / notificação com som durante o motif.
- Desconectar o fone no meio de uma nota.
- Girar o aparelho durante o exercício.
- Matar o app no meio da sessão e reabrir — volta de onde?

**Hipótese a derrubar:** sem `WidgetsBindingObserver`, o motif provavelmente
continua tocando em background, e o `_enabledAt` (âncora do tempo de reação)
conta o tempo em que o app esteve fora. Se confirmar, o tempo de reação que o
Epic 2 vai consumir está contaminado.

### C3 — Sessão longa (40 min, emulador serve)

**Missão:** responder os 23 exercícios em sequência, sem sair da tela.

- O app degrada? Memória, travadas, atraso crescente no áudio?
- Algum exercício repete de forma estranha? São 23 exercícios sobre 13 specs.
- O `AudioPlayer` acumula recursos ao longo da sessão?
- A tela de fim de loop aparece corretamente? Dá para voltar e refazer?
- Toques rápidos: responder antes do motif terminar, tocar "Ouvir de novo"
  repetidamente, tocar "Continuar" duas vezes.

### C4 — Tempo de reação em aparelho real (30 min, aparelho físico)

**Missão:** o tempo de reação medido faz sentido?

`_enabledAt` é fixado quando o motif termina; o RT é a diferença até o toque.
Num aparelho real há latência de áudio, latência de toque e o tempo humano.

- Responder o mais rápido possível — o RT registrado é plausível (>150 ms)?
- Usar "Ouvir de novo" várias vezes e então responder — o RT reflete o tempo
  desde o primeiro motif ou desde o último? (Por design, replays **não** resetam
  a âncora — confirmar que é isso mesmo que se quer.)
- Deixar o exercício parado 2 minutos e responder — o RT gigante é registrado?

**Por que importa:** é o insumo do Medidor de Habilidade do Epic 2. Um RT
sistematicamente errado envenena a story 2.3 inteira.

### C5 — Acessibilidade real (45 min, aparelho físico)

**Missão:** usar o app com TalkBack ligado, sem olhar para a tela.

- Dá para completar um exercício inteiro só com TalkBack?
- As opções são anunciadas com nome e papel? O resultado (certo/errado) é
  anunciado ou só aparece visualmente?
- Escala de texto do sistema no máximo — o card quebra? (O e2e testa isso em
  widget; num aparelho o resultado pode diferir.)
- Contraste em luz forte, e no modo escuro num quarto escuro.
- O banner de erro de áudio é perceptível sem cor?

### C6 — Caminhos de erro no mundo real (30 min)

- Modo avião (o app não usa rede — confirmar que nada quebra mesmo assim).
- Armazenamento cheio: o banco Drift falha? A tela de erro/retry aparece?
- Instalar por cima de uma versão anterior.
- Primeira abertura em aparelho novo, sem dados.

## O que você NÃO consegue explorar hoje

**iOS.** O `AudioSession` entrou na PR #17 e continua **sem nenhuma verificação
de reprodução**. O job `build-ios` prova que o alvo compila e nada mais. Rodar em
iPhone exige macOS + Xcode para assinar e instalar — não dá a partir desta
máquina Linux.

Isso deixa em aberto exatamente o que o `AudioSessionConfiguration.music()` foi
implementado para resolver: som com a chave de silêncio ligada, foco de áudio
contra outro app tocando, comportamento em chamada. **É o maior risco não
mitigado do Epic 1**, e ele não fecha sem um Mac e um aparelho.

## Como registrar

Uma folha por sessão, no formato SBTM. O que importa é separar **observação** de
**interpretação** — exploratório perde valor quando o relato já vem com a
conclusão embutida.

```
CHARTER:     C1 — ouvir o app
DATA/DURAÇÃO: 2026-09-__ / 90 min
AMBIENTE:    Pixel 7, Android 15, fone com fio / build <sha>

O QUE FIZ
- ...

O QUE VI  (fatos, sem interpretação)
- ...

BUGS
- ...

PERGUNTAS / RISCOS
- ...

TEMPO: exploração __% | investigação de bug __% | setup __%
```

Sessões viram entrada em `_bmad-output/test-artifacts/`; bugs viram issue ou
item no `deferred-work.md` com dono — e, pela regra do
`tool/check_deferred_owners.dart`, com dono que o CI consegue cobrar.
