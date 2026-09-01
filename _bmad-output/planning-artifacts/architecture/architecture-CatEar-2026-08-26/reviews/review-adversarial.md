# Review Adversarial — ARCHITECTURE-SPINE.md (Perfect Ear)

Método: para cada AD, construí um par concreto de implementações que obedecem a letra da regra mas divergem de forma incompatível quando integradas. Cada achado é um buraco na especificação, não uma violação de regra existente.

---

## Achado 1 — `SessionResultReported`: contrato de evento subespecificado (AD-2)

AD-2 nomeia o evento (`SessionResultReported`) e diz que ele carrega "acertos, erros, tipo de erro, tempo de reação", mas não fixa: shape exato (payload de campos vs. objeto de sessão inteiro), tipos, unidades, granularidade (um evento por sessão vs. um por tentativa/nota), nem o mecanismo de transporte (Stream/Riverpod, callback síncrono, fila).

**Par divergente:**

- Dev A (Exercícios) implementa, achando que "resultado de sessão" é agregado:
  ```dart
  class SessionResultReported {
    final String sessionId;
    final int correctCount;
    final int incorrectCount;
    final Duration avgReactionTime;
    final Map<String, int> errorTypeCounts; // ex: {'inversao': 2}
  }
  ```
- Dev B (Exercícios, outro exercício/tela) implementa granularidade por tentativa, porque "tipo de erro" e "tempo de reação" fazem mais sentido por resposta individual:
  ```dart
  class SessionResultReported {
    final String sessionId;
    final List<AttemptResult> attempts; // cada um com correct, errorType?, reactionTimeMs
  }
  class AttemptResult {
    final bool correct;
    final String? errorType; // string livre, sem enum
    final int reactionTimeMs; // int, não Duration
  }
  ```

Progressão, ao consumir os dois, recebe formatos incompatíveis (agregado vs. lista de tentativas; `Duration` vs. `int` ms; `errorType` como chave de mapa fixo vs. string livre nullable). Cálculo de Medidor de Habilidade/Esforço diverge conforme qual exercício disparou o evento — exatamente a inconsistência que AD-2 diz prevenir, mas não previne, porque o contrato do evento em si não é normativo.

**Fecho proposto:** Nova AD (ou extensão de AD-2) fixando o schema exato de `SessionResultReported` como classe única em `domain/` compartilhado (ex: `core/events/` ou `progressao/domain/` exportado como contrato), com: granularidade obrigatória (por tentativa, dentro de uma lista, mesmo para sessões de 1 tentativa), enum fechado (`sealed class ErrorType`) em vez de string livre, unidade de tempo fixada (`Duration`, não `int`), e versionamento do evento (campo `schemaVersion` ou equivalente) para evolução futura.

---

## Achado 2 — Dono do "erro" como conceito de currículo vs. conceito de exercício (AD-2 × AD-4)

AD-4 diz que Currículo é dono do conteúdo pedagógico, incluindo referências e schema fixo "estágio → exercícios → tipo → referências de áudio". AD-2 diz que Exercícios reporta "tipo de erro" a Progressão. Nenhuma AD diz **onde o vocabulário de `tipo de erro` é definido** — é taxonomia de Currículo (ex: erro é definido por qual acorde/intervalo foi confundido com qual, dado do catálogo) ou é taxonomia de Exercícios (ex: erro é sobre a interação, tipo "tocou tarde", "inverteu ordem")?

**Par divergente:**

- Dev A modela `errorType` como referência ao catálogo de Currículo: `errorType = 'confused_m3_with_M3'` (dado semântico de teoria musical, definido em `curriculo/domain/`).
- Dev B modela `errorType` como enum de interação do próprio módulo Exercícios: `errorType = ErrorKind.wrongInterval | ErrorKind.timeout | ErrorKind.wrongNote`, sem referência ao catálogo.

Ambos obedecem AD-2 (reportam via evento) e AD-4 (Exercícios não embute dados de currículo na lógica — em ambos os casos, tecnicamente não embutem lógica, só o vocabulário do campo). Progressão recebe semânticas incompatíveis do mesmo campo, e a UI de Progresso (que supostamente mostra "seus erros mais comuns") não consegue exibir de forma consistente entre exercícios escritos por devs diferentes.

**Fecho proposto:** AD explícita definindo o dono da taxonomia de erro: ou (a) Currículo define um catálogo fechado de tipos de erro versionado junto ao schema JSON (AD-4 estendida), e Exercícios só referencia IDs desse catálogo no evento; ou (b) fixar um enum `sealed class ErrorType` único em `core/` ou `progressao/domain/`, compartilhado por todos os módulos que reportam erros.

---

## Achado 3 — "Decisão de dificuldade adaptativa" é escrita por Progressão, mas consultada de onde e quando por Exercícios (AD-2 × AD-5)

AD-2: Progressão é o único que escreve a decisão de dificuldade adaptativa; outros módulos "só leem via `domain/` do Progressão". AD-5: toda mutação segue `UI → Notifier → Repository → Drift`, leitura é reativa via stream/provider. Não é especificado **o momento em que Exercícios lê a dificuldade** — no início da sessão (snapshot) ou continuamente (reativo, podendo mudar em runtime)? E se a sessão já começou com uma dificuldade e o medidor de Progressão muda no meio (outro exercício rodando em paralelo, teoricamente impossível em mobile single-session, mas nada impede leitura duplicada em builds concorrentes de tela)?

**Par divergente:**

- Dev A (Exercícios) lê a dificuldade uma vez ao montar a tela de exercício (snapshot via `ref.read`), guarda em estado local do Notifier de Exercícios, e a sessão inteira roda com esse valor fixo.
- Dev B (Exercícios, outra tela) assina o provider reativo (`ref.watch`) da dificuldade de Progressão durante toda a sessão, então se o usuário voltar da tela e Progressão recalcular (ex: outro fluxo gravou um resultado tardio), a dificuldade muda a meio da sessão em andamento.

Isso não quebra "single-writer" literalmente (só Progressão escreve), mas produz comportamento de produto incompatível entre exercícios — um trava a dificuldade por sessão, outro não — e nenhuma AD define o contrato de leitura (snapshot-per-session vs. reativo-live) que Exercícios deve seguir.

**Fecho proposto:** AD adicional fixando que a leitura de dificuldade adaptativa (e Baseline) por Exercícios é sempre snapshot no início da sessão (ex: `Exercicios` captura o valor via `ref.read` e o congela em um objeto `SessionConfig` imutável passado ao Notifier da sessão), nunca reativo durante uma sessão em andamento — junto com definição do que constitui "início de sessão".

---

## Achado 4 — Schema do catálogo de Currículo "fixo" mas não definido (AD-4)

AD-4 diz "schema fixo (estágio → exercícios → tipo → referências de áudio → presença/intensidade do scaffold de cor)" mas isso é uma descrição em prosa, não um schema. Nenhum arquivo JSON Schema, nenhuma classe Dart de referência, nenhum exemplo é fixado na spine.

**Par divergente:**

- Dev A modela o JSON com `stages: [{id, exercises: [{type, audioRefs: [...], colorScaffold: {enabled, intensity}}]}]` — arrays aninhados.
- Dev B modela como mapa achatado indexado por ID: `{"stage_1.interval_recognition.m3": {audioRef: "...", colorIntensity: 0.5}}` — chaves compostas, sem aninhamento.

Ambos "expõem o conteúdo como catálogo de dados versionado (JSON empacotado como asset), com schema fixo" — cada um decidiu que SEU schema é o fixo. O parser em `curriculo/domain/` que Dev A escreve não lê o JSON que Dev B gerou (e vice-versa), e como o asset é compilado no bundle, isso só quebra em runtime/build, não em compile-time do Dart.

**Fecho proposto:** Anexar um JSON Schema real (ou pelo menos um exemplo canônico completo de 1 stage) como companion da spine (`curriculo-schema.json`), referenciado por AD-4, e versionado junto com o catálogo (`schemaVersion` no próprio JSON) — não deixar "schema fixo" como afirmação sem artefato.

---

## Achado 5 — `AudioService`: contrato único, mas resultado de avaliação de afinação não tipado (AD-3)

AD-3 fixa que toda avaliação de afinação vocal passa por `AudioService`, mas não define o shape do retorno de "avaliação de afinação" — nem a unidade (cents de desvio? Hz? nota mais próxima + delta?), nem se é um Stream contínuo (durante a gravação) ou um resultado único pós-gravação.

**Par divergente:**

- Dev A (Nivelamento) espera `AudioService.evaluatePitch(...)` retornar `Future<PitchResult>` com `PitchResult { detectedNote: String, centsOff: double }` — resultado único ao final da gravação.
- Dev B (Exercícios) espera um `Stream<PitchSample>` contínuo com `PitchSample { frequencyHz: double, timestampMs: int }`, processando pitch em tempo real para feedback visual durante a gravação.

Como a interface real do `AudioService` (`domain/` do módulo Áudio) provavelmente será implementada por quem construir primeiro, o segundo módulo consumidor descobre em integração que a API não atende seu caso de uso (sync vs. stream), forçando ou duplicação de acesso a `record`/pitch lib fora de `AudioService` (violando AD-3 na prática) ou retrabalho da interface.

**Fecho proposto:** AD-3 estendida (ou nova AD) fixando a assinatura mínima de `AudioService` para avaliação de afinação, incluindo explicitamente se expõe both um modo Stream (tempo real) e um modo Future (resultado agregado), e a unidade canônica de desvio de afinação (recomendado: cents, `double`, relativo à nota alvo esperada — não Hz cru, que exige o consumidor saber a nota alvo pra interpretar).

---

## Resumo dos buracos

| # | AD(s) afetada(s) | Buraco |
|---|---|---|
| 1 | AD-2 | `SessionResultReported` sem schema/granularidade/unidades fixados |
| 2 | AD-2 × AD-4 | Taxonomia de "tipo de erro" sem dono definido (Currículo vs. Exercícios) |
| 3 | AD-2 × AD-5 | Contrato de leitura de dificuldade adaptativa (snapshot vs. reativo) não definido |
| 4 | AD-4 | "Schema fixo" do catálogo de currículo sem artefato de schema real |
| 5 | AD-3 | Shape/modo (Stream vs. Future) e unidade do resultado de `AudioService.evaluatePitch` não definidos |
