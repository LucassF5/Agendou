# Agendou

Agenda de plantões para iOS. O usuário cadastra a escala do vínculo (12x36, 24x48, 24x72 ou personalizada) e o app preenche o calendário sozinho. Plantão avulso, cancelamento e anotação do dia são marcados à mão.

Tudo roda no aparelho: sem backend, sem conta, sem rede. Backup é o do próprio iPhone, mais exportar/importar em JSON.

## Requisitos

- Xcode 27+
- iOS 26+ (iPhone)

## Estrutura

```
Agendou.xcodeproj        pastas sincronizadas: arquivo novo em Agendou/ entra no target sozinho
Agendou/                 app SwiftUI (Swift 6, MainActor por padrão)
  App/                   entrada e abas
  Features/              uma pasta por aba: Home, Calendar, Categories, Settings
  Resources/             Assets.xcassets, Localizable.xcstrings (pt-BR)
Config/                  entitlements (App Group group.com.lucasfranco.agendou)
Packages/AgendouCore/    Swift package com dois módulos:
  AgendouCore             lógica pura da escala e do calendário civil, sem SwiftUI nem SwiftData
  AgendouStore            modelos SwiftData e AgendaStore, a única porta de escrita (regras testadas)
```

## Abrindo no Xcode

Na raiz do repositório:

```sh
open Agendou.xcodeproj
```

`xed .` ou duplo clique em `Agendou.xcodeproj` no Finder também servem. O projeto já referencia o package local `Packages/AgendouCore`, e o Xcode resolve ele sozinho na primeira abertura.

Com o projeto aberto: scheme `Agendou`, um simulador de iPhone como destino na barra de cima, ⌘R.

Pra rodar num iPhone de verdade, o team em Signing & Capabilities precisa ter acesso ao App Group `group.com.lucasfranco.agendou`, e o iPhone precisa estar com o Modo de Desenvolvedor ligado.

## Rodando pela linha de comando

App:

```sh
xcodebuild -project Agendou.xcodeproj -scheme Agendou \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Testes do núcleo e das regras de dados (Swift Testing, rodam no Mac, sem simulador):

```sh
swift test --package-path Packages/AgendouCore
```

Pra rodar esses testes pelo Xcode com ⌘U, abrir o package direto: `xed Packages/AgendouCore`. O ⌘U no `Agendou.xcodeproj` roda os testes de interface (`AgendouUITests`), não os do package.

Testes de interface (simulador; o app abre com `-ui-testing`, num banco em memória):

```sh
xcodebuild -project Agendou.xcodeproj -scheme Agendou \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Formatação

`swift-format` vem com o Xcode; a configuração está em `.swift-format`.

```sh
swift format lint --strict --recursive Agendou Packages
swift format --in-place --recursive Agendou Packages
```

## Convenções

- Uma branch por feature a partir da `main`: `feature/...`, `fix/...`, `chore/...`.
- Commits em inglês no padrão Conventional Commits: `feat(calendar): add month grid`.
- Toda mudança entra na `main` por pull request revisado.
