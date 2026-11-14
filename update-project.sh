#!/usr/bin/env bash
###############################################################################
# update-project.sh
#
# Fixes the npm ERESOLVE dependency conflict, updates Angular + related
# dependencies, simplifies/cleans up the code, and modernizes the GitHub
# workflows for ng-github-action-pages.
#
# Root cause of the failure: package.json declared `typescript: "7.0"`, which
# resolved to typescript@7.0.2. @angular-devkit/build-angular@22.2.7 requires
# typescript ">=6.0 <6.1" and @typescript-eslint/parser@8.72.2 requires
# typescript ">=4.8.4 <6.1.0", so the tree could not be resolved.
###############################################################################
set -euo pipefail

cd "$(dirname "$0")"

log() { printf '\n==> %s\n' "$*"; }

###############################################################################
# 1. package.json: resolve dependency tree + drop deprecated/unused packages
###############################################################################
log "Rewriting package.json (fixed dependency tree, Angular 22.x, TS 6.0.x)"

cat > package.json <<'EOF'
{
  "name": "ng-github-action-pages",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build",
    "build:production": "ng build --configuration production",
    "test": "ng test",
    "lint": "ng lint"
  },
  "dependencies": {
    "@angular/animations": "^22.2.6",
    "@angular/common": "^22.2.6",
    "@angular/compiler": "^22.2.6",
    "@angular/core": "^22.2.6",
    "@angular/forms": "^22.2.6",
    "@angular/platform-browser": "^22.2.6",
    "@angular/platform-browser-dynamic": "^22.2.6",
    "@angular/router": "^22.2.6",
    "node-forge": "^1.4.3",
    "rxjs": "~7.8.2",
    "tslib": "^2.9.1",
    "zone.js": "~0.16.0"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^22.2.7",
    "@angular/cli": "^22.2.7",
    "@angular/compiler-cli": "^22.2.6",
    "@angular/language-service": "^22.2.6",
    "@types/jasmine": "^7.0.0",
    "@types/node": "^26.6.6",
    "@typescript-eslint/eslint-plugin": "^8.72.2",
    "@typescript-eslint/parser": "^8.72.2",
    "eslint": "^10.15.0",
    "jasmine-core": "~7.0.2",
    "jasmine-spec-reporter": "^7.0.0",
    "karma": "^6.4.4",
    "karma-chrome-launcher": "~3.2.0",
    "karma-coverage-istanbul-reporter": "~3.0.3",
    "karma-jasmine": "~5.1.0",
    "karma-jasmine-html-reporter": "^2.3.0",
    "typescript": "~6.0.0"
  }
}
EOF

# 2. TypeScript config: drop deprecated Angular compiler options
log "Cleaning up tsconfig.json"
python3 - <<'PY'
import json
p = "tsconfig.json"
with open(p) as f:
    cfg = json.load(f)
aco = cfg.setdefault("angularCompilerOptions", {})
aco.pop("fullTemplateTypeCheck", None)
aco.pop("strictInjectionParameters", None)
aco["strictTemplates"] = True
with open(p, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY

###############################################################################
# 3. angular.json: drop deprecated flags + Protractor e2e target
###############################################################################
log "Cleaning up angular.json"
python3 - <<'PY'
import json
p = "angular.json"
with open(p) as f:
    cfg = json.load(f)

proj = cfg["projects"]["ng-github-action-pages"]["architect"]

# build: AOT is the default since Angular 9, remove the redundant flag
build = proj.setdefault("build", {})
build.pop("aot", None)

# test: keep Karma unit tests
# e2e: Protractor is deprecated/removed, drop the target and its configs
proj.pop("e2e", None)

with open(p, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY

###############################################################################
# 4. Simplify / modernize the source code (standalone component)
###############################################################################
log "Modernizing source code (standalone app, no NgModule boilerplate)"

cat > src/main.ts <<'EOF'
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app/app.component';

bootstrapApplication(AppComponent)
  .catch((err) => console.error(err));
EOF

cat > src/app/app.component.ts <<'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  standalone: true,
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent {
  title = 'ng-github-action-pages';
}
EOF

cat > src/app/app.component.spec.ts <<'EOF'
import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [AppComponent] });
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance).toBeTruthy();
  });

  it(`should have as title 'ng-github-action-pages'`, () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.title).toEqual('ng-github-action-pages');
  });
});
EOF

# Remove the obsolete NgModule (no longer needed with a standalone app)
rm -f src/app/app.module.ts

# Replace the bloated default welcome template with a clean, minimal one
cat > src/app/app.component.html <<'EOF'
<header class="toolbar">
  <img src="favicon.ico" alt="Angular Logo" width="32" height="32" />
  <span>Welcome to {{ title }}</span>
</header>

<main class="content">
  <h1>{{ title }} app is running!</h1>
  <p>
    This is an Angular 22 application deployed to GitHub Pages via GitHub
    Actions. The project was cleaned up: standalone components, TypeScript 6,
    ESLint (TSLint removed), Protractor/e2e removed, and modernized workflows.
  </p>
</main>
EOF

cat > src/styles.css <<'EOF'
/* Global styles */
:host {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 16px;
  color: #333;
  box-sizing: border-box;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background-color: #1976d2;
  color: white;
  font-weight: 600;
}

.toolbar img {
  border-radius: 4px;
}

.content {
  max-width: 720px;
  margin: 40px auto;
  padding: 0 16px;
}

.content h1 {
  font-size: 1.5rem;
  margin: 0 0 12px;
}

.content p {
  margin: 0 0 16px;
  line-height: 1.6;
}
EOF

# Unit test environment file stays compatible with the standalone spec
cat > src/test.ts <<'EOF'
// This file is required by karma.conf.js and loads recursively all the .spec and framework files

import 'zone.js/dist/zone-testing';
import { getTestBed } from '@angular/core/testing';
import {
  BrowserDynamicTestingModule,
  platformBrowserDynamicTesting
} from '@angular/platform-browser-dynamic/testing';

// First, initialize the Angular testing environment.
getTestBed().initTestEnvironment(
  BrowserDynamicTestingModule,
  platformBrowserDynamicTesting()
);
EOF

###############################################################################
# 5. Remove deprecated tooling (TSLint + Protractor/e2e) + ESLint config
###############################################################################
log "Removing TSLint and Protractor/e2e, adding ESLint config"
rm -f tslint.json
rm -rf e2e

cat > .eslintrc.json <<'EOF'
{
  "root": true,
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaVersion": 2022,
    "sourceType": "module",
    "project": ["tsconfig.json", "tsconfig.app.json", "tsconfig.spec.json"]
  },
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended-type-checked"
  ],
  "rules": {
    "@typescript-eslint/no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }]
  }
}
EOF

###############################################################################
# 6. GitHub workflows: modernize actions + Node.js setup
###############################################################################
log "Modernizing GitHub workflows"

mkdir -p .github/workflows

cat > .github/workflows/main.yml <<'EOF'
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Build (production)
        run: npm run build:production

      - name: Deploy to GitHub Pages
        uses: JamesIves/github-pages-deploy-action@releases/v4
        if: github.ref == 'refs/heads/master'
        with:
          token: ${{ secrets.ACCESS_TOKEN }}
          branch: gh-pages
          folder: dist/ng-github-action-pages
EOF

cat > .github/workflows/codeql-analysis.yml <<'EOF'
name: "CodeQL"

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
  schedule:
    - cron: '0 7 * * 4'

jobs:
  analyse:
    name: Analyse
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
EOF

###############################################################################
# 7. README: drop obsolete references
###############################################################################
log "Updating README.md"
python3 - <<'PY'
p = "README.md"
with open(p) as f:
    readme = f.read()
readme = readme.replace(
    "This project was generated with [Angular CLI](https://github.com/angular/angular-cli) version 8.3.22.",
    "This project is an Angular 22 application."
)
old_e2e = """## Running end-to-end tests

Run `ng e2e` to execute the end-to-end tests via [Protractor](http://www.protractortest.org/).

"""
readme = readme.replace(old_e2e, "")
readme = readme.replace("ng update @angular-devkit/build-angular\n", "")
with open(p, "w") as f:
    f.write(readme)
PY

###############################################################################
# 8. Reinstall dependencies from a clean slate
###############################################################################
log "Clean reinstall: removing node_modules/ and package-lock.json"
rm -rf node_modules package-lock.json

log "Running npm install"
npm install

log "Done. Verify with: npm run build:production"
printf '\nNext steps:\n'
printf '  npm run build:production   # production build\n'
printf '  npm run lint               # ESLint\n'
printf '  git add -A && git commit -m "chore: fix dependency tree, modernize project"\n'
