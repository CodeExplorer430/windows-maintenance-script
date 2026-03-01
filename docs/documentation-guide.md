# Documentation Guide

This project uses [MkDocs](https://www.mkdocs.org/) with the [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) theme to build and maintain its documentation site. This ensures a modern, highly readable, and easily navigable structure for end-users and developers.

## Prerequisites

To serve and build the documentation locally, you'll need Python installed on your system. 

1. Install Python (if not already installed):
   - You can download it from [python.org](https://www.python.org/downloads/) or install it via winget:
     ```powershell
     winget install -e --id Python.Python.3.11
     ```

2. Install MkDocs and the Material Theme:
   Open your terminal and run:
   ```powershell
   pip install mkdocs-material
   ```

## Running the Documentation Locally

To preview your changes to the documentation in real-time, MkDocs provides a built-in development server. 

Navigate to the root directory of the project (where `mkdocs.yml` is located) and run:

```powershell
mkdocs serve
```

This command will:
- Build the documentation.
- Start a local web server (usually at `http://127.0.0.1:8000/`).
- Automatically reload the page whenever you save a Markdown file.

## Project Structure

The documentation configuration and content reside primarily in two places:

- **`mkdocs.yml`**: The configuration file located in the repository root. It defines the site name, author, theme, layout, and navigation structure.
- **`docs/`**: This directory contains the actual Markdown files.

```text
windows-maintenance-script/
├── mkdocs.yml
└── docs/
    ├── index.md             # Home page
    ├── installation.md      # Getting Started
    ├── user-guide.md        # User manual
    └── ...
```

## Adding or Editing Content

1. Create a new `.md` file inside the `docs/` folder (or a subfolder).
2. Use standard Markdown or the extended features provided by Material for MkDocs (like Admonitions, Code Blocks with Tabs, Mermaid charts, etc.).
3. Add the new file to the `nav` section in `mkdocs.yml` so it appears in the side navigation menu:

```yaml
nav:
  - Home: index.md
  - Getting Started: installation.md
  # Add your new page here
  - My New Topic: my-new-topic.md 
```

## Building for Production

If you ever need to generate the static HTML files (for instance, to host them manually without a CI/CD pipeline like GitHub Pages), run:

```powershell
mkdocs build
```

This creates a `site/` directory containing all the static assets and HTML files ready for deployment. The `.gitignore` is already configured to exclude this folder from source control.
