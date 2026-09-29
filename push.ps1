# Отправляет политику конфиденциальности в публичный репозиторий
# smysly-privacy (GitHub Pages) без запроса логина: используется токен
# из переменной окружения GITHUB_TOKEN.
#
# Запуск:
#   $env:GITHUB_TOKEN='<personal access token с правом repo>'
#   powershell -ExecutionPolicy Bypass -File push.ps1
#
# Токен создаётся тут: https://github.com/settings/tokens (scope: repo).

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$owner = 'happyvolkovajulia-ai'
$repo = 'smysly-privacy'
$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Host 'Не задан GITHUB_TOKEN.' -ForegroundColor Yellow
    Write-Host 'Создайте токен: https://github.com/settings/tokens (scope repo)' -ForegroundColor Yellow
    Write-Host 'Затем:  $env:GITHUB_TOKEN=''ghp_...''; .\push.ps1' -ForegroundColor Yellow
    exit 1
}

$api = "https://api.github.com/repos/$owner/$repo"
$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = 'application/vnd.github+json'
    'User-Agent'           = 'smysly-release'
    'X-GitHub-Api-Version' = '2022-11-28'
}

# 1. Создаём репозиторий, если его ещё нет.
try {
    $null = Invoke-RestMethod -Uri $api -Headers $headers -Method Get
    Write-Host "Репозиторий уже существует: $owner/$repo" -ForegroundColor Cyan
} catch {
    Write-Host "Создаю репозиторий $owner/$repo" -ForegroundColor Cyan
    $body = @{
        name        = $repo
        description = 'Политика конфиденциальности приложения «Смыслы»'
        private     = $false
        has_issues  = $false
        has_wiki    = $false
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Headers $headers -Method Post -Body $body
}

# 2. Готовим локальный репозиторий.
if (-not (Test-Path (Join-Path $here '.git'))) {
    git init -b main | Out-Null
}
git config user.name 'happyvolkovajulia-ai'
git config user.email 'happyvolkovajulia-ai@users.noreply.github.com'
git add index.html README.md push.ps1 2>$null
if (-not (git diff --cached --quiet)) {
    git commit -q -m 'Политика конфиденциальности приложения «Смыслы»'
} else {
    Write-Host 'Изменений нет — файлы уже закоммичены.' -ForegroundColor Yellow
}

# 3. Отправляем через HTTPS с токеном (без интерактивного логина).
$remote = "https://$owner`:$token@github.com/$owner/$repo.git"
if (git remote get-url origin 2>$null) {
    git remote set-url origin $remote
} else {
    git remote add origin $remote
}
git push -u origin main

# 4. Включаем GitHub Pages.
try {
    $pages = @{ source = @{ branch = 'main'; path = '/' } } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$api/pages" -Headers $headers -Method Post -Body $pages
    Write-Host 'GitHub Pages включены.' -ForegroundColor Green
} catch {
    Write-Host 'GitHub Pages: возможно, уже включены или требуют ручного включения.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host "Готово. Адрес политики: https://$owner.github.io/$repo/" -ForegroundColor Green
