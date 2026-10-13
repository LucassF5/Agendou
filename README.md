# Agendou

Agenda de plantões para iOS. O usuário cadastra os locais onde trabalha e a escala de cada um (12x36, 24x48, 24x72 ou personalizada) e o app preenche o calendário sozinho. Plantão avulso, cancelamento, troca de horário e anotação do dia são marcados à mão.

Tudo roda no aparelho: sem backend, sem conta, sem rede. Backup é o do próprio iPhone, mais exportar/importar em JSON.

## O que o app faz

- **Início**: o plantão em andamento ou o próximo, com quanto falta; os próximos dias e plantões; as horas e os plantões do mês, até hoje e no mês todo, por local. Escala perto do fim aparece aqui com o botão "Renovar".
- **Calendário**: o mês com um ponto na cor de cada local, o resumo de horas e plantões do mês e a visão do ano. Tocar num dia abre os plantões dele: adicionar um extra, editar o horário, cancelar (e restaurar), excluir e escrever a anotação do dia. O "+" marca vários dias de uma vez, num local sem escala fixa, ou registra a mudança de escala de um local que tem. "Enviar" gera o mês como imagem ou texto, para os locais escolhidos; as anotações não vão junto.
- **Escalas**: os locais, cada um com nome, cor e, se tiver, escala fixa. A escala vale por 1, 3 ou 6 meses, ou até um último dia, e pode ser renovada, trocada ou corrigida; o histórico fica guardado. Um local sem escala fixa recebe os dias marcados à mão. Local pode ser arquivado ou excluído.
- **Ajustes**: lembrete diário, só nos dias com plantão, no horário escolhido; exportar e importar os dados em JSON (importar substitui tudo, depois de confirmar); rever o tutorial; versão.
- **Primeira abertura**: uma introdução e um tour de 9 passos sobre as telas de verdade, rodando numa agenda de exemplo que só existe em memória.
- **Widget do próximo plantão**: na tela de início (pequeno e médio) e na de bloqueio (retangular e circular).

## Vocabulário

| Na tela | No código | O que é |
|---|---|---|
| Local | `ShiftCategory` | Onde a pessoa trabalha: nome e cor. Não se chama `Category` por colidir com o Objective-C |
| Escala | `CategorySchedule` | Trabalha X horas, folga Y horas, a partir de um plantão âncora e por um período. Mudar a escala fecha a versão e abre outra |
| Marcação | `ShiftOverride` | Plantão extra, ou cancelamento de um plantão da escala |
| Anotação | `DayNote` | Texto livre de um dia |

## Requisitos

- Xcode 27+
- iOS 18.6+ (iPhone)

## Estrutura

```
Agendou.xcodeproj        pastas sincronizadas: arquivo novo em Agendou/, AgendouShared/, AgendouWidget/ ou AgendouUITests/ entra no target sozinho
Agendou/                 app SwiftUI (Swift 6, MainActor por padrão)
  App/                   entrada e abas
  Features/              Home, Calendar, Schedules (aba Escalas), Settings e Tour (introdução e tour da primeira abertura)
  Shared/                apoio só do app: lembretes do sistema, mensagens de erro, dados de preview
  Resources/             Assets.xcassets, Localizable.xcstrings (pt-BR)
AgendouWidget/           extensão do widget do próximo plantão (com o Localizable.xcstrings dela)
AgendouShared/           código compilado no app e no widget: formatação e cores
AgendouUITests/          testes de interface (XCUITest)
Config/                  entitlements (App Group group.com.lucasfranco.agendou) e Info.plist do widget
Packages/AgendouCore/    Swift package com dois módulos:
  AgendouCore             lógica pura, sem SwiftUI nem SwiftData: motor da escala, calendário civil, resumos do mês e planos do compartilhamento, dos lembretes e do widget
  AgendouStore            modelos SwiftData, AgendaStore (a única porta de escrita, regras testadas), backup em JSON e lembretes
```

O banco é SwiftData, no container do App Group. O widget abre o mesmo banco só pra leitura (`AgendouContainer.makeReadOnly()`): quem cria e migra é o app. Ao mudar um modelo, crie a próxima `AgendouSchemaVN` e o estágio no `AgendouMigrationPlan`.

Datas e horários são sempre do fuso America/Sao_Paulo (`CivilCalendar.timeZone`) e em pt-BR, seja qual for a configuração do aparelho.

## Abrindo no Xcode

Na raiz do repositório:

```sh
open Agendou.xcodeproj
```

`xed .` ou duplo clique em `Agendou.xcodeproj` no Finder também servem. O projeto já referencia o package local `Packages/AgendouCore`, e o Xcode resolve ele sozinho na primeira abertura.

Com o projeto aberto: scheme `Agendou`, um simulador de iPhone como destino na barra de cima, ⌘R. O widget vai embutido no app e compila junto. Pra vê-lo, abra `AgendouWidget/NextShiftWidget.swift` e use os previews (um por tamanho).

Pra rodar num iPhone de verdade, o team em Signing & Capabilities precisa ter acesso ao App Group `group.com.lucasfranco.agendou` nos dois targets (`Agendou` e `AgendouWidget`, bundle `com.lucasfranco.agendou.widget`), e o iPhone precisa estar com o Modo de Desenvolvedor ligado.

## Rodando pela linha de comando

App (com o widget):

```sh
xcodebuild -project Agendou.xcodeproj -scheme Agendou \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Testes do núcleo e das regras de dados (Swift Testing, rodam no Mac, sem simulador):

```sh
swift test --package-path Packages/AgendouCore
```

Pra rodar esses testes pelo Xcode com ⌘U, abrir o package direto: `xed Packages/AgendouCore`. O ⌘U no `Agendou.xcodeproj` roda os testes de interface (`AgendouUITests`), não os do package.

Testes de interface (simulador):

```sh
xcodebuild -project Agendou.xcodeproj -scheme Agendou \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- O app abre com `-ui-testing`: banco em memória, primeira abertura limpa e um agendador de lembretes de mentira, então nada chega ao iPhone de verdade. O argumento `-skip-tutorial` pula a introdução e o tour. `XCUIApplication.agendou()` manda os dois; `agendou(tutorial: true)` deixa o tutorial aparecer.
- A suíte inteira leva uns 15 minutos. Pra rodar uma classe só, acrescente `-only-testing:AgendouUITests/SchedulesTests`.
- Se o `xcodebuild` falhar com `failed to launch … RequestDenied`, inicialize o simulador antes: `xcrun simctl boot <id>` e `xcrun simctl bootstatus <id> -b`.

## Formatação

`swift-format` vem com o Xcode; a configuração está em `.swift-format`.

```sh
swift format lint --strict --recursive Agendou AgendouShared AgendouWidget AgendouUITests Packages
swift format --in-place --recursive Agendou AgendouShared AgendouWidget AgendouUITests Packages
```

## Convenções

- Uma branch por feature a partir da `main`: `feature/...`, `fix/...`, `chore/...`.
- Commits em inglês no padrão Conventional Commits: `feat(calendar): add month grid`.
- Toda mudança entra na `main` por pull request revisado.
- Ao subir a versão, atualize o `MARKETING_VERSION` do app e o do widget (iguais) e a versão que `SettingsTests.testOffersBackupAndShowsTheVersion` espera.
