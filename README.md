# 🐓 Carijó Notes

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-Proprietary-gray)]()

**Carijó Notes** é uma aplicação de gestão de conhecimento pessoal (PKM) *local-first*, desenvolvida para programadores e criativos que precisam de uma ponte veloz entre o pensamento efêmero e a publicação estruturada.

> **"Cisque suas ideias. Cante para o mundo."**

---

## ✨ Funcionalidades

### 📝 Editor & Organização
- **Editor Markdown** com preview em tempo real e syntax highlighting
- **Navegação Bidirecional** — links `[[Nota]]` com backlinks automáticos (Zettelkasten)
- **Frontmatter YAML** — metadados ricos para cada nota
- **Árvore de Pastas** — organização hierárquica das notas
- **Sistema de Tags** — filtragem e categorização
- **Templates** — crie notas a partir de modelos
- **Daily Notes** — notas diárias automáticas

### ⚡ Produtividade
- **Quick Capture** (`Ctrl+N`) — captura instantânea de ideias
- **Command Palette** (`Ctrl+K`) — navegação e comandos rápidos
- **IA Speech-to-Text** — Transcreva notas de voz usando **OpenAI Whisper** ou **Google Gemini**
- **Auto-Save** — salvamento automático com debounce
- **Fuzzy Search** — busca inteligente em todas as notas (incluindo busca profunda indexada)

### 🔗 Graph View
- **Visualização de Grafo** — veja suas notas como uma rede interconectada
- **Animação Force-Directed** — layout orgânico em tempo real
- **Interação** — arraste nós, veja conexões ao hover

### 🎨 Temas
6 temas profissionais incluídos:
| Tema | Estilo |
|------|--------|
| **Carijó Dark** | Preto matte com acento vermelho |
| **Dracula** | Roxo e rosa clássico |
| **Nord** | Azul polar minimalista |
| **Gruvbox** | Tons quentes retrô |
| **Solarized Dark** | Paleta científica |
| **Monokai Pro** | Amarelo vibrante |

### 🚀 Sincronização & Deploy
- **Git Integration** — staging area visual, commits e push direto para seu blog/repositório
- **Supabase Sync** — backup e sincronização em tempo real na nuvem
- **Sync Wizard** — configurador interativo para Git e Supabase, facilitando o setup inicial

---

## 🏗️ Arquitetura

```
lib/
├── main.dart           # Entry point com MultiProvider
├── screens/            # 4 telas principais
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   ├── deploy_screen.dart
│   └── graph_view_screen.dart
├── services/           # Estado reativo (ChangeNotifier)
│   ├── note_service.dart
│   ├── git_service.dart
│   ├── supabase_service.dart
│   └── theme_service.dart
├── domain/             # Clean Architecture
│   ├── models/
│   ├── repositories/
│   └── use_cases/
└── widgets/            # UI Components
```

---

## 🛠️ Stack Tecnológica

| Categoria | Tecnologia |
|-----------|------------|
| **Framework** | Flutter Desktop (Windows) |
| **State Management** | Provider |
| **Database** | Isar (indexação local) |
| **Markdown** | flutter_markdown + flutter_math_fork |
| **Cloud Sync** | Supabase |
| **VCS** | Git CLI |
| **IA/STT** | OpenAI API & Google Generative AI (Gemini) |
| **Tipografia** | Google Fonts (JetBrains Mono & Space Grotesk) |

---

## ⌨️ Atalhos de Teclado

| Atalho | Ação |
|--------|------|
| `Ctrl+K` | Command Palette |
| `Ctrl+N` | Quick Capture |
| `Ctrl+S` | Salvar nota atual |
| `Ctrl+B` | Negrito |
| `Ctrl+I` | Itálico |
| `Ctrl+Shift+P` | Command Palette (alternativo) |

---

## 🚀 Como Executar

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.0.0
- Windows 10/11
- Git (opcional, para funcionalidade de deploy)

### Instalação

```bash
# 1. Clone o repositório
git clone <url-do-repositorio>
cd carijo_notes

# 2. Instale as dependências
flutter pub get

# 3. Gere os arquivos do Isar
dart run build_runner build

# 4. Execute o aplicativo
flutter run -d windows
```

---

## 📁 Dados & Privacidade

- **100% Local-First** — suas notas são arquivos `.md` no seu computador
- **Sem telemetria** — nenhum dado é coletado
- **Você é dono dos seus dados** — exporte quando quiser

---

## 🗺️ Roadmap para Aplicativo funcional (Uso Pessoal)

- [ ] **Exportação Avançada**: Suporte a PDF e HTML para compartilhamento.
- [ ] **Backups Automáticos**: Sistema de backup local em ZIP para segurança extra.
- [ ] **Busca Global Profunda**: Visualização de trechos de conteúdo em todos os arquivos nota.
- [ ] **Gerenciamento de Vault**: Ferramentas para renomear pastas e tags em massa (refactoring).
- [ ] **Segurança**: Bloqueio opcional por PIN ou Biometria.
- [ ] **Companion Mobile**: App básico em Flutter compartilhando o backend Supabase.
- [x] Plugins e extensões (Sistema base implementado)
- [ ] Suporte macOS/Linux (Testes de compatibilidade)

---

## 💡 Filosofia: Ciscagem e Canto

A aplicação é construída sobre a metáfora do **Galo Carijó**:

1. **🔍 Ciscagem (Quick Capture)** — Capture ideias instantaneamente, sem fricção
2. **🪺 O Ninho (Knowledge Base)** — Organize via links bidirecionais e metadados
3. **🎤 O Canto (Deploy)** — Publique suas notas para o mundo via Git

---

## 📄 Licença

Projeto proprietário. Todos os direitos reservados.

---

> [!TIP]
> **Use o Carijó Notes para domar o excesso de ideias.** Comece ciscando o que vier à mente e termine cantando suas conquistas para o mundo.
