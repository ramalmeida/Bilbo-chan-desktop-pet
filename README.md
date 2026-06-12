# Bilbo-Chan

Bilbo-Chan e uma aplicacao macOS de mascote de desktop.
Autor: Ramon Almeida

Versao: 1.0.9

Licenca: MIT. Veja `LICENSE`.

# video

https://youtube.com/shorts/gztCU0_ZQPk

## Requisitos

- macOS only


Para recompilar o app a partir do fonte Swift, use Xcode Command Line Tools.

```zsh
xcode-select --install
```

## Como executar

Pelo Terminal:

```zsh
cd macOS
./run.command
```

Abrindo o `.app` pela raiz do projeto:

```zsh
open ./macOS/Bilbo-Chan.app
```

Abrindo o `.app` se voce ja estiver dentro da pasta `macOS`:

```zsh
open ./Bilbo-Chan.app
```

Tambem e possivel dar duplo clique em `run.command` ou em `Bilbo-Chan.app`.

## Permissao de Acessibilidade

Na primeira execucao, o Bilbo-Chan solicita automaticamente as permissoes de Acessibilidade e Input Monitoring do macOS. Essas permissoes sao necessarias para capturar teclado e mouse enquanto outras janelas estao em foco.

Enquanto a permissao nao for concedida, o app continua aberto e mostra um aviso na propria janela. Assim que o macOS confirmar a autorizacao, a captura global e iniciada automaticamente.

Se a permissao for negada ou bloqueada pelo macOS, reabra o app para disparar a solicitacao novamente.

## Escopo

Implementado:

- janela macOS sem borda, sempre no topo;
- arrastar a janela com o mouse;
- fechar a aplicacao com clique direito sobre a janela;
- mascote Bilbo-Chan com bulldog customizado;
- animacao por teclas no modo `keyboard`;
- cada tecla pressionada mantem a animacao visivel por uma janela curta, adequada para digitacao rapida;
- animacao por movimento do mouse;
- captura global por `CGEventTap` com fallback por monitor global do AppKit;
- clique de mouse no modo `standard`;
- captura global via CoreGraphics, sem dependencia externa;
- solicitacao automatica de permissao de Acessibilidade.

Nao implementado:

- editor de configuracao;
- Live2D;
- gamepad;
- rede;
- sons.
- I.A (respostas e consultas web)

Para sair, clique com o botao direito sobre a janela, ou foque a janela e use `Esc` ou `Command+Q`.
