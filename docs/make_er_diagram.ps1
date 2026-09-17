# Построение ER-диаграммы базы данных и экспорт в PNG и PDF.
# Запуск из корня проекта:
#   pwsh -File docs/make_er_diagram.ps1
# PDF печатается через системный принтер «Microsoft Print to PDF».

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$script:Width = 1290
$script:Height = 440
$script:HeaderHeight = 38
$script:RowHeight = 27

$script:Pens = @{
    Border = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#8C8C8C"), 1.4)
    Soft   = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#DDDDDD"), 1.0)
    Link   = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#444444"), 1.8)
}
$script:Brushes = @{
    Dark  = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#1A1A1A"))
    Gray  = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#6B6B6B"))
    White = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    Zebra = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#F5F5F5"))
}
$script:Fonts = @{
    Title  = New-Object System.Drawing.Font("Segoe UI Semibold", 24, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Note   = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Header = New-Object System.Drawing.Font("Segoe UI Semibold", 18, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Key    = New-Object System.Drawing.Font("Segoe UI Semibold", 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Name   = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Type   = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    Link   = New-Object System.Drawing.Font("Segoe UI Semibold", 16, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
}

function New-Row($key, $name, $type) {
    return [pscustomobject]@{ Key = $key; Name = $name; Type = $type }
}

$script:Tables = @(
    [pscustomobject]@{
        Name = "partner"; X = 50; Y = 150; W = 350
        Rows = @(
            (New-Row "PK" "partner_id" "INTEGER"),
            (New-Row "" "company_name" "VARCHAR(150) NOT NULL"),
            (New-Row "U" "inn" "VARCHAR(12) NOT NULL"),
            (New-Row "U" "contact_email" "VARCHAR(150) NOT NULL"),
            (New-Row "" "phone" "VARCHAR(20) NULL"),
            (New-Row "" "rating" "DECIMAL(2,1) NULL"),
            (New-Row "" "created_at" "TIMESTAMP NOT NULL")
        )
    },
    [pscustomobject]@{
        Name = "delivery"; X = 480; Y = 170; W = 340
        Rows = @(
            (New-Row "PK" "delivery_id" "INTEGER"),
            (New-Row "FK" "partner_id" "INTEGER NOT NULL"),
            (New-Row "FK" "product_id" "INTEGER NOT NULL"),
            (New-Row "" "delivery_date" "DATE NOT NULL"),
            (New-Row "" "quantity" "INTEGER NOT NULL"),
            (New-Row "" "total_amount" "DECIMAL(12,2) NOT NULL")
        )
    },
    [pscustomobject]@{
        Name = "product"; X = 890; Y = 220; W = 350
        Rows = @(
            (New-Row "PK" "product_id" "INTEGER"),
            (New-Row "U" "product_name" "VARCHAR(150) NOT NULL")
        )
    }
)

function Get-TableHeight($table) {
    return $script:HeaderHeight + $script:RowHeight * $table.Rows.Count
}

function Draw-Table($g, $table) {
    $height = Get-TableHeight $table
    $g.FillRectangle($script:Brushes.White, $table.X, $table.Y, $table.W, $height)
    $g.FillRectangle($script:Brushes.Dark, $table.X, $table.Y, $table.W, $script:HeaderHeight)
    $g.DrawString($table.Name, $script:Fonts.Header, $script:Brushes.White, [float]($table.X + 14), [float]($table.Y + 9))
    for ($i = 0; $i -lt $table.Rows.Count; $i++) {
        $row = $table.Rows[$i]
        $y = $table.Y + $script:HeaderHeight + $i * $script:RowHeight
        if ($i % 2 -eq 1) {
            $g.FillRectangle($script:Brushes.Zebra, [float]($table.X + 1), [float]$y, [float]($table.W - 2), [float]$script:RowHeight)
        }
        $g.DrawLine($script:Pens.Soft, [float]$table.X, [float]$y, [float]($table.X + $table.W), [float]$y)
        $g.DrawString($row.Key, $script:Fonts.Key, $script:Brushes.Gray, [float]($table.X + 12), [float]($y + 6))
        $g.DrawString($row.Name, $script:Fonts.Name, $script:Brushes.Dark, [float]($table.X + 52), [float]($y + 4))
        $g.DrawString($row.Type, $script:Fonts.Type, $script:Brushes.Gray, [float]($table.X + 175), [float]($y + 6))
    }
    $g.DrawRectangle($script:Pens.Border, $table.X, $table.Y, $table.W, $height)
}

function Draw-Link($g, $fromX, $fromY, $toX, $toY, $fromLabel, $toLabel) {
    $g.DrawLine($script:Pens.Link, [float]$fromX, [float]$fromY, [float]$toX, [float]$toY)
    $g.FillEllipse($script:Brushes.Dark, [float]($fromX - 4), [float]($fromY - 4), 8, 8)
    $g.FillEllipse($script:Brushes.Dark, [float]($toX - 4), [float]($toY - 4), 8, 8)
    $middleX = ($fromX + $toX) / 2
    $g.DrawString($fromLabel, $script:Fonts.Link, $script:Brushes.Dark, [float]($fromX + ($middleX - $fromX) / 3), [float]($fromY - 26))
    $g.DrawString($toLabel, $script:Fonts.Link, $script:Brushes.Dark, [float]($toX - ($toX - $middleX) / 2), [float]($toY - 26))
}

function Draw-Diagram($g) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.FillRectangle($script:Brushes.White, 0, 0, $script:Width, $script:Height)
    $g.DrawString("ER-диаграмма базы данных «Партнеры и отгрузки» (3NF)", $script:Fonts.Title, $script:Brushes.Dark, 50, 46)
    $g.DrawString("PK — первичный ключ, FK — внешний ключ, U — уникальное ограничение. Внешние ключи: ON DELETE RESTRICT.", $script:Fonts.Note, $script:Brushes.Gray, 50, 86)
    $g.DrawString("Связи: партнер 1 — ∞ отгрузка, продукция 1 — ∞ отгрузка.", $script:Fonts.Note, $script:Brushes.Gray, 50, 110)
    foreach ($table in $script:Tables) {
        Draw-Table $g $table
    }
    $partner = $script:Tables[0]
    $delivery = $script:Tables[1]
    $product = $script:Tables[2]
    $partnerY = $partner.Y + (Get-TableHeight $partner) / 2
    $deliveryY = $delivery.Y + (Get-TableHeight $delivery) / 2
    $productY = $product.Y + (Get-TableHeight $product) / 2
    Draw-Link $g ($partner.X + $partner.W) $partnerY $delivery.X $deliveryY "1" "∞"
    Draw-Link $g ($product.X) $productY ($delivery.X + $delivery.W) $deliveryY "1" "∞"
}

$outputDir = $PSScriptRoot
$pngPath = Join-Path $outputDir "er_diagram.png"
$pdfPath = Join-Path $outputDir "er_diagram.pdf"

$scale = 2
$bitmap = New-Object System.Drawing.Bitmap(($script:Width * $scale), ($script:Height * $scale))
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.ScaleTransform($scale, $scale)
Draw-Diagram $graphics
$graphics.Dispose()
$bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "PNG: $pngPath"

if (Test-Path $pdfPath) {
    Remove-Item $pdfPath -Force
}
$document = New-Object System.Drawing.Printing.PrintDocument
$document.DocumentName = "ER-диаграмма"
$document.PrinterSettings.PrinterName = "Microsoft Print to PDF"
$document.PrinterSettings.PrintToFile = $true
$document.PrinterSettings.PrintFileName = $pdfPath
$document.DefaultPageSettings.Landscape = $true
$document.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(50, 50, 50, 50)
$document.add_PrintPage({
    param($caller, $event)
    $g = $event.Graphics
    $g.PageUnit = [System.Drawing.GraphicsUnit]::Pixel
    $areaWidth = $event.MarginBounds.Width / 100.0 * $g.DpiX
    $areaHeight = $event.MarginBounds.Height / 100.0 * $g.DpiY
    $offsetX = $event.MarginBounds.Left / 100.0 * $g.DpiX
    $offsetY = $event.MarginBounds.Top / 100.0 * $g.DpiY
    $fit = [Math]::Min($areaWidth / $script:Width, $areaHeight / $script:Height)
    $g.TranslateTransform([float]$offsetX, [float]$offsetY)
    $g.ScaleTransform([float]$fit, [float]$fit)
    Draw-Diagram $g
    $event.HasMorePages = $false
})
$document.Print()
Write-Host "PDF: $pdfPath"
