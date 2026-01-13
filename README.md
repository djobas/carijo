# 🐓 Carijó Notes

**Carijó Notes** é uma aplicação de gestão de conhecimento pessoal (PKM) *local-first*, desenvolvida sob medida para programadores e criativos que precisam de uma ponte veloz entre o pensamento efêmero e a publicação estruturada.

O projeto elimina o atrito de organização, permitindo que você foque no que importa: **ter a ideia e registrá-la.**

---

## 💡 Filosofia: Ciscagem e Canto

A aplicação é construída sobre a metáfora do **Galo Carijó**, traduzindo-se em três pilares técnicos:

1.  **Ciscagem (Quick Capture):** Captura instantânea de ideias em Markdown. Sem burocracia, sem pastas obrigatórias, sem títulos forçados. Apenas o pensamento puro.
2.  **O Ninho (Knowledge Base):** Suas notas residem localmente, organizadas via links bidirecionais (Zettelkasten) e metadados ricos (YAML Frontmatter).
3.  **O Canto (Deploy):** Integração nativa com Git para transformar suas notas selecionadas em publicações reais no seu blog ou site estático.

## 🎨 Estética: "Carijó Minimal"

Esqueça o rústico ou o lúdico. O Carijó Notes adota uma identidade visual **High-Contrast, Dark Mode e Tipográfica**.

-   **Paleta:** Baseada na plumagem do galo (Preto Matte, Off-White, Cinza) com acentos em **Vermelho Crista** para ações críticas.
-   **Vibe:** Uma ferramenta de trabalho sóbria, focada em texto e código, utilizando fontes *Monospace* para evocar a precisão de um terminal moderno.

## 🚀 Funcionalidades Atuais

O projeto já conta com o seguinte alicerce:

-   [x] **Editor de Markdown:** Edição em tempo real com visualização (Preview) integrada.
-   [x] **Navegação Bidirecional:** Suporte inicial para links `[[Nota]]`.
-   [x] **Quick Capture:** Atalho global para captura rápida de pensamentos.
-   [x] **Command Palette:** `Ctrl+K` para navegação e comandos rápidos.
-   [x] **Staging Area:** Interface para visualização de mudanças prontas para o Git (mock funcional).
-   [x] **Local-First:** Armazenamento direto em arquivos `.md` locais, garantindo a posse total dos seus dados.

## 🛠️ Stack Tecnológica

-   **Framework:** Flutter (Desktop/Windows)
-   **Gerenciamento de Estado:** Provider
-   **Tipografia:** Google Fonts (JetBrains Mono & Space Grotesk)
-   **Markdown:** `flutter_markdown` para renderização e prefixos YAML para metadados.

## 🏗️ Como Executar

1.  Certifique-se de ter o Flutter instalado (`flutter doctor`).
2.  Clone o repositório.
3.  Execute `flutter pub get` na raiz.
4.  Inicie a aplicação: `flutter run -d windows`.

---

> [!TIP]
> **Use o Carijó Notes para domar o excesso de ideias.** Comece ciscando o que vier à mente e termine cantando suas conquistas para o mundo.
