param(
    [Parameter(Mandatory)][string]$ReportDir,
    [Parameter(Mandatory)][string]$TablesDir,
    [ValidateSet('headline', 'downgrading', 'older_pool')][string]$ActivePage = 'headline'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Writes the report's three pages as PBIR files: the dark design of the section 7 brief. Builds every
# file in memory, checks each one parses and every field it uses exists in the model, and only then
# replaces the three page folders. Plain ASCII on purpose: special characters come from [char] codes,
# so Windows PowerShell reads this file correctly without a byte-order mark.

$Dot = [string][char]0x00B7      # middle dot
$Ellipsis = [string][char]0x2026
$EnDash = [string][char]0x2013

# ================================================================ JSON writer (2-space indent)
function Esc([string]$s) {
    $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n').Replace("`t", '\t')
}
function J($o, [int]$lvl = 0) {
    $ind = '  ' * $lvl
    $in1 = '  ' * ($lvl + 1)
    if ($null -eq $o) { return 'null' }
    if ($o -is [string]) { return '"' + (Esc $o) + '"' }
    if ($o -is [bool]) { if ($o) { return 'true' } else { return 'false' } }
    if ($o -is [int] -or $o -is [long]) { return [string]$o }
    if ($o -is [System.Collections.IDictionary]) {
        if ($o.Count -eq 0) { return '{}' }
        $parts = foreach ($k in $o.Keys) { $in1 + '"' + (Esc $k) + '": ' + (J $o[$k] ($lvl + 1)) }
        return "{`n" + ($parts -join ",`n") + "`n$ind}"
    }
    if ($o -is [System.Collections.IEnumerable]) {
        $items = @($o)
        if ($items.Count -eq 0) { return '[]' }
        $parts = foreach ($i in $items) { $in1 + (J $i ($lvl + 1)) }
        return "[`n" + ($parts -join ",`n") + "`n$ind]"
    }
    throw "Cannot write a $($o.GetType().FullName) as JSON"
}

# ================================================================ expression helpers
function L([string]$v) { [ordered]@{ expr = [ordered]@{ Literal = [ordered]@{ Value = $v } } } }
function Q([string]$s) { "'" + $s.Replace("'", "''") + "'" }
function LStr([string]$s) { L (Q $s) }
function LB([bool]$b) { if ($b) { L 'true' } else { L 'false' } }
function LD([double]$n) { L ([string]$n + 'D') }
function LL([int]$n) { L ([string]$n + 'L') }
function Fill([string]$hex) { [ordered]@{ solid = [ordered]@{ color = (LStr $hex) } } }
function P($props, $selector = $null) {
    $o = [ordered]@{ properties = $props }
    if ($null -ne $selector) { $o['selector'] = $selector }
    $o
}
function Src([string]$e) { [ordered]@{ SourceRef = [ordered]@{ Entity = $e } } }
function Col([string]$e, [string]$p) { [ordered]@{ Column = [ordered]@{ Expression = (Src $e); Property = $p } } }
function Mea([string]$p) { [ordered]@{ Measure = [ordered]@{ Expression = (Src '_Measures'); Property = $p } } }
function MeaExpr([string]$p) { [ordered]@{ expr = (Mea $p) } }
function Proj($field, [string]$display) {
    $kind = @($field.Keys)[0]
    $e = $field[$kind]['Expression']['SourceRef']['Entity']
    $p = $field[$kind]['Property']
    [ordered]@{ field = $field; queryRef = "$e.$p"; nativeQueryRef = $p; displayName = $display }
}
function SortBy($field, [string]$dir) {
    [ordered]@{ sort = @( [ordered]@{ field = $field; direction = $dir } ); isDefaultSort = $true }
}
function ScopeEq($field, [string]$literal) {
    [ordered]@{ data = @( [ordered]@{ scopeId = [ordered]@{ Comparison = [ordered]@{
        ComparisonKind = 0; Left = $field; Right = [ordered]@{ Literal = [ordered]@{ Value = $literal } } } } } ) }
}
function Meta([string]$measure) { [ordered]@{ metadata = "_Measures.$measure" } }
# Every data point of one series: the selector measure-driven formatting needs.
function EachPoint([string]$measure) {
    [ordered]@{ data = @( [ordered]@{ dataViewWildcard = [ordered]@{ matchingOption = 1 } } ); metadata = "_Measures.$measure" }
}

# ================================================================ design tokens (the brief)
$Page = '#0B1220'; $Panel = '#131C2E'; $Line = '#24324A'
$Text = '#F1F5F9'; $Text2 = '#94A3B8'; $NavText = '#CBD5E1'
$Orange = '#EB6834'; $Blue = '#4C9BEF'; $Grey = '#64748B'
$Font = 'Segoe UI'; $Semi = 'Segoe UI Semibold'
$W = 1280; $H = 904; $M = 24; $G = 16; $Pad = 16

# ================================================================ container pieces
function Bg([string]$hex) {
    if ($hex) { P ([ordered]@{ show = (LB $true); color = (Fill $hex); transparency = (LD 0) }) }
    else { P ([ordered]@{ show = (LB $false) }) }
}
function Pad4([int]$t, [int]$b, [int]$l, [int]$r) { P ([ordered]@{ top = (LD $t); bottom = (LD $b); left = (LD $l); right = (LD $r) }) }
function Edge([string]$hex, [int]$radius) { P ([ordered]@{ show = (LB $true); color = (Fill $hex); radius = (LD $radius); width = (LD 1) }) }
function Hidden { P ([ordered]@{ show = (LB $false) }) }
function AltText([string]$t) { P ([ordered]@{ altText = (LStr $t) }) }
function ChartTitle([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (LStr $t); fontFamily = (LStr $Semi); fontSize = (LD 12); bold = (LB $false)
                   fontColor = (Fill $Text); titleWrap = (LB $true) })
}
function ChartSub([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (LStr $t); fontFamily = (LStr $Font); fontSize = (LD 9.5)
                   fontColor = (Fill $Text2); titleWrap = (LB $true) })
}
# A panel: the brief's #131C2E fill, 1 px #24324A border, radius 12, no shadow, 16 px padding.
function PanelObjects([string]$title, [string]$sub, [string]$alt) {
    $o = [ordered]@{
        background   = @( (Bg $Panel) )
        border       = @( (Edge $Line 12) )
        dropShadow   = @( (Hidden) )
        padding      = @( (Pad4 $Pad $Pad $Pad $Pad) )
        title        = @( $(if ($title) { ChartTitle $title } else { Hidden }) )
        subTitle     = @( $(if ($sub) { ChartSub $sub } else { Hidden }) )
        visualHeader = @( (Hidden) )
        general      = @( (AltText $alt) )
    }
    $o
}
# No panel: transparent, no border, no padding unless asked.
function FlatObjects([string]$bgHex, [int[]]$pad, [string]$alt) {
    [ordered]@{
        background   = @( (Bg $bgHex) )
        border       = @( (Hidden) )
        dropShadow   = @( (Hidden) )
        padding      = @( (Pad4 $pad[0] $pad[1] $pad[2] $pad[3]) )
        title        = @( (Hidden) )
        subTitle     = @( (Hidden) )
        visualHeader = @( (Hidden) )
        general      = @( (AltText $alt) )
    }
}
function TooltipHeader {
    $p = [ordered]@{ show = (LB $true); showTooltipButton = (LB $true); transparency = (LD 100) }
    foreach ($k in 'showVisualInformationButton', 'showDrillRoleSelector', 'showDrillUpButton', 'showDrillToggleButton',
                   'showDrillDownLevelButton', 'showDrillDownExpandButton', 'showPinButton', 'showFilterRestatementButton',
                   'showFocusModeButton', 'showCopyVisualImageButton', 'showSeeDataLayoutToggleButton', 'showOptionsMenu',
                   'showCommentButton', 'showPersonalizeVisualButton', 'showSmartNarrativeButton', 'showSetAlertButton',
                   'showFollowVisualButton') { $p[$k] = (LB $false) }
    P $p
}

# ================================================================ pages and visuals
$visualSchema = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.4.0/schema.json'
$pageSchema   = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
$pagesSchema  = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json'
$pages = [ordered]@{}
$script:z = 0

function NewPage([string]$name, [string]$display) {
    $pages[$name] = [ordered]@{ Display = $display; Visuals = (New-Object System.Collections.Generic.List[object]) }
    $script:z = 0
}
# Decorative visuals (panels, strips, divider) are drawn behind and come last in the tab order.
function AddVisual([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $visual, $filterConfig = $null, [switch]$Decorative) {
    $script:z += 1000
    $o = [ordered]@{
        '$schema' = $visualSchema
        name      = $name
        position  = [ordered]@{ x = $x; y = $y; z = $script:z; height = $h; width = $w; tabOrder = 0 }
        visual    = $visual
    }
    if ($null -ne $filterConfig) { $o['filterConfig'] = $filterConfig }
    $pages[$page].Visuals.Add([pscustomobject]@{ Json = $o; Decorative = [bool]$Decorative })
}

# ---- text
function Run([string]$text, [double]$pt, [string]$color, [bool]$bold = $false, [string]$family = '') {
    $style = [ordered]@{}
    if ($family) { $style['fontFamily'] = $family }
    if ($bold) { $style['fontWeight'] = 'bold' }
    $style['fontSize'] = [string]$pt + 'pt'
    if ($color) { $style['color'] = $color }
    [ordered]@{ value = $text; textStyle = $style }
}
function Para($runs, [string]$align = '') {
    $o = [ordered]@{ textRuns = @($runs) }
    if ($align) { $o['horizontalTextAlignment'] = $align }
    $o
}
function Spacer([double]$pt) { Para @( (Run ' ' $pt '') ) }
# Text with **bold** spans, for the takeaways' key numbers.
function RichRuns([string]$markup, [double]$pt, [string]$color) {
    $parts = $markup -split '\*\*'
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ne '') { Run $parts[$i] $pt $color (($i % 2) -eq 1) $Font }
    }
}
function TextVisual($paragraphs, $containerObjects) {
    [ordered]@{
        visualType = 'textbox'
        objects = [ordered]@{ general = @( (P ([ordered]@{ paragraphs = @($paragraphs) })) ) }
        visualContainerObjects = $containerObjects
        drillFilterOtherVisuals = $true
    }
}
# A block of colour: panels, accent strips and the divider are text boxes with a fill.
function AddBlock([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, [string]$fill, [string]$border, [int]$radius) {
    $objs = FlatObjects $fill @(0, 0, 0, 0) 'Decorative'
    if ($border) { $objs['border'] = @( (Edge $border $radius) ) }
    AddVisual $page $name $x $y $w $h (TextVisual @( (Spacer 1) ) $objs) -Decorative
}

# ---- the new card visual as a left-aligned line of text driven by a measure
function Off2 { @( (P ([ordered]@{ show = (LB $false) })), (P ([ordered]@{ show = (LB $false) }) ([ordered]@{ id = 'default' })) ) }
function CardText([string]$measure, [string]$display, [double]$pt, [string]$color, [string]$family, [string]$align, [string]$alt, [string]$tip = '') {
    $container = FlatObjects '' @(0, 0, 0, 0) $alt
    if ($tip) {
        $container['visualHeader'] = @( (TooltipHeader) )
        $container['visualHeaderTooltip'] = @( (P ([ordered]@{ text = (LStr $tip); fontSize = (LD 10) })) )
    }
    [ordered]@{
        visualType = 'cardVisual'
        query = [ordered]@{ queryState = [ordered]@{ Data = [ordered]@{ projections = @( (Proj (Mea $measure) $display) ) } } }
        objects = [ordered]@{
            value        = @( (P ([ordered]@{ show = (LB $true); fontSize = (LD $pt); fontFamily = (LStr $family); fontColor = (Fill $color)
                                              horizontalAlignment = (LStr $align); labelDisplayUnits = (LD 1) })) )
            label        = @( (P ([ordered]@{ show = (LB $false) }) ([ordered]@{ id = 'default' })) )
            # No tile or callout decoration: set off both for the visual and for its one card.
            fillCustom      = (Off2)
            outline         = (Off2)
            shadowCustom    = (Off2)
            glowCustom      = (Off2)
            accentBar       = (Off2)
            cardCalloutArea = (Off2)
            padding      = @( (P ([ordered]@{ paddingSelection = (LStr 'Custom'); leftMargin = (LL 0); topMargin = (LL 0)
                                              bottomMargin = (LL 0); rightMargin = (LL 0) }) ([ordered]@{ id = 'default' })) )
            layout       = @( (P ([ordered]@{ cellPadding = (LL 0); alignment = (LStr 'top'); orientation = (LD 0)
                                              columnCount = (LL 1); rowCount = (LL 1) })) )
            spacing      = @( (P ([ordered]@{ verticalSpacing = (LL 0) }) ([ordered]@{ id = 'default' })) )
        }
        visualContainerObjects = $container
        drillFilterOtherVisuals = $true
    }
}

# ---- the frame every page shares
$NavAlt = 'Page navigation: The headline, Downgrading, An older pool'
$Source = "Source: APRA quarterly private health insurance statistics, June 2026 release, and annual membership and benefits statistics 2024${EnDash}25. Population: ABS, as published by APRA. Titles and takeaways describe the June 2026 release."
function AddFrame([string]$page, [string]$eyebrow, [string]$question, [string]$takeaway, [string]$footnote) {
    $header = @(
        (Para @( (Run $eyebrow 9 $Text2 $false $Semi) )),
        (Para @( (Run $question 22 $Text $false $Semi) ))
    )
    AddVisual $page 'header' $M $M 720 64 (TextVisual $header (FlatObjects '' @(0, 0, 0, 0) "$eyebrow. $question"))

    $nav = [ordered]@{
        visualType = 'pageNavigator'
        objects = [ordered]@{
            fill = @(
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $Page); transparency = (LD 100) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $Panel); transparency = (LD 0) }) ([ordered]@{ id = 'hover' })),
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $Text); transparency = (LD 0) }) ([ordered]@{ id = 'selected' }))
            )
            text = @(
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $NavText); fontSize = (LD 10); fontFamily = (LStr $Font) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $Page); fontSize = (LD 10); fontFamily = (LStr $Semi) }) ([ordered]@{ id = 'selected' }))
            )
            outline = @(
                (P ([ordered]@{ show = (LB $true); lineColor = (Fill $Line); weight = (LD 1); transparency = (LD 0) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); lineColor = (Fill $Text); weight = (LD 1); transparency = (LD 0) }) ([ordered]@{ id = 'selected' }))
            )
        }
        visualContainerObjects = (FlatObjects '' @(0, 0, 0, 0) $NavAlt)
        drillFilterOtherVisuals = $true
    }
    AddVisual $page 'page_navigator' 848 $M 408 32 $nav
    AddVisual $page 'data_period' 848 60 408 20 (CardText 'Data Period' 'Data period' 9 $Text2 $Font 'right' 'The period the APRA data on this report covers')
    AddBlock $page 'divider' $M 96 ($W - 2 * $M) 1 $Line '' 0
    AddVisual $page 'takeaway' $M 112 ($W - 2 * $M) 48 (TextVisual @( (Para @( RichRuns $takeaway 12 $Text )) ) (FlatObjects '' @(0, 0, 0, 0) ($takeaway -replace '\*\*', '')))

    # Footer: footnote, then the source with the repository right-aligned on its last line.
    if ($footnote) {
        AddVisual $page 'footnote' $M 812 ($W - 2 * $M) 32 (TextVisual @( (Para @( (Run $footnote 8.5 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $footnote))
    }
    AddVisual $page 'source' $M 848 968 32 (TextVisual @( (Para @( (Run $Source 8.5 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $Source))
    AddVisual $page 'repository' 1008 864 248 16 (TextVisual @( (Para @( (Run 'github.com/Nandita-choudhary/phi-coverage' 8.5 $Text2 $false $Font) ) 'right') ) (FlatObjects '' @(0, 0, 0, 0) 'github.com/Nandita-choudhary/phi-coverage'))
}

# ---- KPI tile: label on top, then the value, then a context line, with a 4 px accent strip
function AddKpi([string]$page, [string]$name, [int]$x, [int]$w, [string]$label, [string]$labelMeasure, [string]$valueMeasure, [string]$contextMeasure, [string]$strip, [string]$tip) {
    $y = 176; $h = 104
    AddBlock $page "${name}_panel" $x $y $w $h $Panel $Line 12
    AddBlock $page "${name}_strip" ($x + $Pad) ($y + $Pad) 4 ($h - 2 * $Pad) $strip $strip 2
    $tx = $x + $Pad + 16; $tw = $w - 2 * $Pad - 16
    if ($labelMeasure) {
        AddVisual $page "${name}_label" $tx ($y + 12) $tw 20 (CardText $labelMeasure 'Label' 10 $Text2 $Font 'left' $label)
    } else {
        AddVisual $page "${name}_label" $tx ($y + 12) $tw 20 (TextVisual @( (Para @( (Run $label 10 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $label))
    }
    AddVisual $page "${name}_value" $tx ($y + 30) $tw 46 (CardText $valueMeasure $label 26 $Text $Semi 'left' "$label. $tip" $tip)
    AddVisual $page "${name}_context" $tx ($y + 76) $tw 20 (CardText $contextMeasure 'Context' 10 $Text2 $Font 'left' "Context for $label")
}

# ---- text panel: heading, then paragraphs; each paragraph is a list of runs
function AddTextPanel([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, [string]$heading, $paragraphs, [string]$alt) {
    $paras = @( (Para @( (Run $heading 12 $Text $false $Semi) )) )
    foreach ($runs in $paragraphs) { $paras += (Spacer 5); $paras += (Para @($runs)) }
    $objs = FlatObjects $Panel @($Pad, $Pad, $Pad, $Pad) $alt
    $objs['border'] = @( (Edge $Line 12) )
    AddVisual $page $name $x $y $w $h (TextVisual $paras $objs)
}

# ---- charts
$Quarter = Col 'dim_date' 'quarter_end'
function AxisObjects([bool]$scalar, [bool]$valueAxis, [bool]$millions) {
    $cat = [ordered]@{ show = (LB $true); labelColor = (Fill $Text2); fontSize = (LD 9); fontFamily = (LStr $Font)
                       gridlineShow = (LB $false); showAxisTitle = (LB $false) }
    if ($scalar) { $cat['axisType'] = (LStr 'Scalar') }
    $val = [ordered]@{ show = (LB $valueAxis); labelColor = (Fill $Text2); fontSize = (LD 9); fontFamily = (LStr $Font)
                       gridlineShow = (LB $valueAxis); gridlineColor = (Fill $Line); showAxisTitle = (LB $false) }
    if ($millions) { $val['labelDisplayUnits'] = (LD 1000000); $val['labelPrecision'] = (LL 1) }
    [ordered]@{
        categoryAxis = @( (P $cat) )
        valueAxis    = @( (P $val) )
        legend       = @( (Hidden) )
    }
}
# Line chart. Each series: Measure, Label, Color, KeyLabel (a measure, blank except at the points to
# label), SeriesLabel (show the series name at the line's end), NameColor.
function LineVisual($series, [string]$title, [string]$sub, [bool]$millions, $refY, $refX, [bool]$seriesNames) {
    $objects = AxisObjects $true $true $millions
    $objects['dataPoint'] = @( @($series) | ForEach-Object { P ([ordered]@{ fill = (Fill $_.Color) }) (Meta $_.Measure) } )
    $objects['lineStyles'] = @( (P ([ordered]@{ strokeWidth = (LD 2); showMarker = (LB $false) })) )
    $labels = @( (P ([ordered]@{ show = (LB $true); color = (Fill $Text); fontSize = (LD 9); fontFamily = (LStr $Font)
                                  labelDensity = (LD 100); enableBackground = (LB $true); backgroundColor = (Fill $Panel)
                                  backgroundTransparency = (LD 0) })) )
    foreach ($s in @($series)) {
        $seriesLabel = [ordered]@{ showSeries = (LB $true); showDynamicLabels = (LB $true); color = (Fill $Text) }
        if ($s.LabelPosition) { $seriesLabel['labelPosition'] = (LStr $s.LabelPosition) }
        $labels += (P $seriesLabel (Meta $s.Measure))
        $labels += (P ([ordered]@{ showDynamicLabels = (LB $true); dynamicLabelValue = (MeaExpr $s.KeyLabel); showBlankAs = (LStr '') }) (EachPoint $s.Measure))
    }
    $objects['labels'] = $labels
    if ($seriesNames) {
        $names = @( (P ([ordered]@{ show = (LB $true); textSize = (LD 9); seriesFontFamily = (LStr $Font); enableBackground = (LB $false) })) )
        foreach ($s in @($series)) { $names += (P ([ordered]@{ seriesMatchColor = (LB $false); seriesColor = (Fill $s.NameColor) }) (Meta $s.Measure)) }
        $objects['seriesLabels'] = $names
    }
    if ($null -ne $refY) { $objects['y1AxisReferenceLine'] = @( $refY ) }
    if ($null -ne $refX) { $objects['xAxisReferenceLine'] = @( $refX ) }
    [ordered]@{
        visualType = 'lineChart'
        query = [ordered]@{
            queryState = [ordered]@{
                Category = [ordered]@{ projections = @( (Proj $Quarter 'Quarter') ) }
                Y = [ordered]@{ projections = @( @($series) | ForEach-Object { Proj (Mea $_.Measure) $_.Label } ) }
            }
            sortDefinition = (SortBy $Quarter 'Ascending')
        }
        objects = $objects
        visualContainerObjects = (PanelObjects $title $sub "$title. $sub")
        drillFilterOtherVisuals = $true
    }
}
# A dashed horizontal line whose value and label come from measures.
function RefLineY([string]$valueMeasure, [string]$labelMeasure, [string]$hAlign) {
    P ([ordered]@{
        show = (LB $true)
        displayName = (MeaExpr $labelMeasure)
        value = (MeaExpr $valueMeasure)
        lineColor = (Fill $Grey)
        transparency = (LD 0)
        style = (LStr 'dashed')
        position = (LStr 'back')
        dataLabelShow = (LB $true)
        dataLabelText = (LStr 'Name')
        dataLabelColor = (Fill $Text2)
        dataLabelHorizontalPosition = (LStr $hAlign)
        dataLabelVerticalPosition = (LStr 'above')
    }) ([ordered]@{ id = '1' })
}
function FromDate([string]$name, [string]$display, [string]$iso) {
    [ordered]@{ filters = @( [ordered]@{
        name = $name
        displayName = $display
        field = (Col 'dim_date' 'quarter_end')
        type = 'Advanced'
        filter = [ordered]@{
            Version = 2
            From = @( [ordered]@{ Name = 'd'; Entity = 'dim_date'; Type = 0 } )
            Where = @( [ordered]@{ Condition = [ordered]@{ Comparison = [ordered]@{
                ComparisonKind = 2
                Left = [ordered]@{ Column = [ordered]@{ Expression = [ordered]@{ SourceRef = [ordered]@{ Source = 'd' } }; Property = 'quarter_end' } }
                Right = [ordered]@{ Literal = [ordered]@{ Value = "datetime'$iso'" } }
            } } } )
        }
    } ) }
}
function ColumnVisual($category, [string]$categoryName, [string]$measure, [string]$measureName, $tooltips, $colourRules, [string]$title, [string]$sub, $refY, [bool]$byValue) {
    $objects = AxisObjects $false $false $false
    $objects['dataPoint'] = @( (P ([ordered]@{ fill = (Fill $Grey) })) ) + @( $colourRules | ForEach-Object { P ([ordered]@{ fill = (Fill $Orange) }) (ScopeEq $category $_) } )
    # A panel-coloured background behind each label, so a dashed line never runs through the text.
    $objects['labels'] = @( (P ([ordered]@{ show = (LB $true); color = (Fill $Text); fontSize = (LD 9); fontFamily = (LStr $Font)
                                             enableBackground = (LB $true); backgroundColor = (Fill $Panel); backgroundTransparency = (LD 0) })) )
    if ($null -ne $refY) {
        $objects['y1AxisReferenceLine'] = @( $refY )
        # Room at the left edge for the line's label, clear of the first column's data label.
        $objects['categoryAxis'][0].properties['outerPadding'] = (LL 150)
    }
    $state = [ordered]@{
        Category = [ordered]@{ projections = @( (Proj $category $categoryName) ) }
        Y        = [ordered]@{ projections = @( (Proj (Mea $measure) $measureName) ) }
    }
    if ($tooltips) { $state['Tooltips'] = [ordered]@{ projections = @( $tooltips | ForEach-Object { Proj (Mea $_.Measure) $_.Label } ) } }
    # Lowest value first, or the category's own order (age bands sort by their first age).
    $sort = if ($byValue) { SortBy (Mea $measure) 'Ascending' } else { SortBy $category 'Ascending' }
    [ordered]@{
        visualType = 'clusteredColumnChart'
        query = [ordered]@{ queryState = $state; sortDefinition = $sort }
        objects = $objects
        visualContainerObjects = (PanelObjects $title $sub "$title. $sub")
        drillFilterOtherVisuals = $true
    }
}

# ================================================================ page 1: the headline
NewPage 'headline' 'The headline'
$pg = 'headline'
AddFrame $pg ("1 OF 3 $Dot THE HEADLINE") "Membership is at a record. Isn't everything fine?" `
    "Not quite. A record **12.8 million** people hold hospital cover, but since 2015 Australia's population has grown faster than membership. The share covered, **45.8%**, is still below its June 2015 peak of **47.4%**." ''
AddKpi $pg 'kpi_insured'  24  296 'People with hospital cover' '' 'Insured Persons' 'Insured Persons Context' $Blue 'People with private hospital cover at the end of the latest quarter, Australia-wide.'
AddKpi $pg 'kpi_change'   336 296 'Change on a year earlier' '' 'Insured Persons, Change on a Year Earlier' 'Insured Persons Change Context' $Blue 'People with hospital cover, against the same quarter a year earlier.'
AddKpi $pg 'kpi_coverage' 648 296 'Share of Australians covered' '' 'Coverage Rate' 'Coverage Rate Context' $Orange "People with hospital cover as a share of Australia's population, at the end of the latest quarter."
AddKpi $pg 'kpi_policies' 960 296 'Hospital policies' '' 'Hospital Policies' 'Hospital Policies Context' $Grey 'Hospital policies at the end of the latest quarter. One policy can cover several people.'

AddVisual $pg 'insured_by_quarter' 24 296 608 280 (LineVisual @( @{ Measure = 'Insured Persons'; Label = 'People with hospital cover'; Color = $Blue; KeyLabel = 'Insured Persons Key Label' } ) `
    'A record 12.8 million people now have hospital cover, up 40% since 2007' `
    'People with hospital cover at the end of each quarter, Australia-wide, in millions.' $true $null $null $false)
AddVisual $pg 'coverage_by_quarter' 648 296 608 280 (LineVisual @( @{ Measure = 'Coverage Rate'; Label = 'Share covered'; Color = $Orange; KeyLabel = 'Coverage Rate Key Label' } ) `
    "${Ellipsis}but the share of Australians covered, 45.8%, is still below its 2015 peak of 47.4%" `
    'People with hospital cover as a share of the population, at the end of each quarter.' $false (RefLineY 'Coverage Rate Peak' 'Coverage Rate Peak Label' 'left') $null $false)

AddTextPanel $pg 'how_numbers_work' 24 592 480 240 'How the numbers work' @(
    , @( (Run "Coverage is people with hospital cover divided by Australia's population." 10 $Text2 $false $Font) )
    , @( (Run "People, policies and population are counted at the end of each quarter, so a period's figure is its latest quarter, never a sum." 10 $Text2 $false $Font) )
    , @( (Run "Every figure traces back to a cell in APRA's spreadsheets. The five published figures on the right were rebuilt from them and match at the precision they were published." 10 $Text2 $false $Font) )
) "How the numbers work. Coverage is people with hospital cover divided by Australia's population. People, policies and population are counted at the end of each quarter, so a period's figure is its latest quarter, never a sum. Every figure traces back to a cell in APRA's spreadsheets. The five published figures on the right were rebuilt from them and match at the precision they were published."

# Reconciliation table: five rows, no scroll bars; widths leave room for cell padding.
$recon = @(
    @{ Field = (Col 'reconciliation_panel' 'measure'); Label = 'Measure'; Width = 380 },
    @{ Field = (Col 'reconciliation_panel' 'published_display'); Label = 'Published'; Width = 75 },
    @{ Field = (Col 'reconciliation_panel' 'ours_display'); Label = 'Rebuilt'; Width = 75 },
    @{ Field = (Mea 'Reconciliation Source'); Label = 'Source'; Width = 70 },
    @{ Field = (Mea 'Reconciliation Match'); Label = 'Match'; Width = 60 }
)
$tableTitle = "5 of 5 published figures reproduced from APRA's raw data"
$table = [ordered]@{
    visualType = 'tableEx'
    query = [ordered]@{ queryState = [ordered]@{ Values = [ordered]@{ projections = @( $recon | ForEach-Object { Proj $_.Field $_.Label } ) } } }
    objects = [ordered]@{
        total = @( (P ([ordered]@{ totals = (LB $false) })) )
        columnHeaders = @( (P ([ordered]@{ fontColor = (Fill $Text2); backColor = (Fill $Panel); fontFamily = (LStr $Semi); fontSize = (LD 9) })) )
        values = @( (P ([ordered]@{ fontColorPrimary = (Fill $Text); backColorPrimary = (Fill $Panel); fontColorSecondary = (Fill $Text)
                                     backColorSecondary = (Fill $Panel); fontFamily = (LStr $Font); fontSize = (LD 10) })),
                    (P ([ordered]@{ fontColor = (Fill $Blue) }) (EachPoint 'Reconciliation Match')) )
        grid = @( (P ([ordered]@{ gridVertical = (LB $false); gridHorizontal = (LB $true); gridHorizontalColor = (Fill $Line)
                                   gridHorizontalWeight = (LD 1); outlineColor = (Fill $Line); rowPadding = (LD 4) })) )
        columnWidth = @( $recon | ForEach-Object { P ([ordered]@{ value = (LD $_.Width) }) ([ordered]@{ metadata = (Proj $_.Field '').queryRef }) } )
    }
    visualContainerObjects = (PanelObjects $tableTitle '' $tableTitle)
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'reconciliation' 520 592 736 240 $table

# ================================================================ page 2: downgrading
NewPage 'downgrading' 'Downgrading'
$pg = 'downgrading'
AddFrame $pg ("2 OF 3 $Dot DOWNGRADING") 'Are people downgrading instead of leaving?' `
    'In aggregate, yes. Policies grew **43.5%** since 2007, but only **26.8%** now give full cover, down from **63.6%**. And **29.4%** carry an excess over 500 dollars, up from **0.5%** before the April 2019 rule change.' `
    'Full cover means no exclusions and no reduced cover. APRA counts the mix of policies at each quarter end, not who switched, so thinner cover can come from members downgrading or from new members buying less.'
AddKpi $pg 'kpi_policies'   24  400 'Hospital policies' '' 'Hospital Policies' 'Hospital Policies Context' $Blue 'Hospital policies at the end of the latest quarter. One policy can cover several people.'
AddKpi $pg 'kpi_full_cover' 440 400 'With full cover' '' 'Full Cover Share' 'Full Cover Share Context' $Orange 'Share of hospital policies with full cover: no reduced cover and no lifetime exclusions. Latest quarter.'
AddKpi $pg 'kpi_excess'     856 400 'With an excess over 500 dollars' '' 'Excess Over 500 Share' 'Excess Over 500 Share Context' $Orange 'Share of hospital policies with an excess over 500 dollars for a single person. Latest quarter.'

# Left column: full cover over the state chart, which gets the extra height so its data labels and
# the "Australia" line label do not collide. Right column: the excess chart over the panel.
AddVisual $pg 'full_cover_by_quarter' 24 296 608 240 (LineVisual @( @{ Measure = 'Full Cover Share'; Label = 'With full cover'; Color = $Orange; KeyLabel = 'Full Cover Share Key Label' } ) `
    'Policies grew 43.5% since 2007, but only 26.8% now give full cover, down from 63.6%' `
    'Share of hospital policies with full cover, at the end of each quarter.' $false $null $null $false)

$ruleLine = P ([ordered]@{
    show = (LB $true)
    displayName = (LStr '1 Apr 2019: maximum excess rises to 750 dollars single')
    value = (L "datetime'2019-04-01T00:00:00'")
    lineColor = (Fill $Grey)
    transparency = (LD 0)
    style = (LStr 'dashed')
    position = (LStr 'front')
    dataLabelShow = (LB $false)
}) ([ordered]@{ id = '1' })
AddVisual $pg 'excess_by_quarter' 648 296 608 272 (LineVisual @( @{ Measure = 'Excess Over 500 Share'; Label = 'Excess over 500 dollars'; Color = $Orange; KeyLabel = 'Excess Over 500 Share Key Label' } ) `
    'Since the April 2019 rule change, policies with an excess over 500 dollars went from 0.5% to 29.4%' `
    "Share of hospital policies with an excess over 500 dollars (single), from September 2010. Earlier quarters are left out: the share drops 4.1 points that quarter, and APRA's notes do not explain why." `
    $false $null $ruleLine $false) (FromDate 'fromSep2010' 'From September 2010' '2010-09-30T00:00:00')
# The rule-change note sits left of the dashed line (about x 985) and above the flat pre-2019 line.
$ruleNote = @(
    (Para @( (Run '1 Apr 2019: maximum excess' 9 $Text2 $false $Font) ) 'right'),
    (Para @( (Run 'rises to 750 dollars single' 9 $Text2 $false $Font) ) 'right')
)
AddVisual $pg 'excess_rule_note' 711 460 230 48 (TextVisual $ruleNote (FlatObjects '' @(0, 0, 0, 0) '1 April 2019: maximum excess rises to 750 dollars single'))

$stateCode = Col 'dim_state' 'state'
AddVisual $pg 'full_cover_by_state' 24 552 608 244 (ColumnVisual $stateCode 'State' 'Full Cover Share' 'With full cover' $null @("'WA'") `
    'Full cover is rarest in WA (23.1%) and most common in Tasmania (38.7%)' 'Share of hospital policies with full cover, latest quarter, against Australia as a whole.' `
    (RefLineY 'Full Cover Share, Australia' 'Full Cover Share, Australia Label' 'left') $true)

AddTextPanel $pg 'less_cover_means' 648 584 608 212 'What less cover means' @(
    , @( (Run 'Exclusions: ' 10 $Text $false $Semi), (Run 'treatments a policy does not pay for at all.' 10 $Text2 $false $Font) )
    , @( (Run 'Reduced cover: ' 10 $Text $false $Semi), (Run 'treatments a policy pays only reduced benefits for.' 10 $Text2 $false $Font) )
    , @( (Run 'Excess: ' 10 $Text $false $Semi), (Run 'what you pay towards a hospital admission before the insurer pays. Since 1 April 2019 it can be up to 750 dollars for a single person, up from 500.' 10 $Text2 $false $Font) )
    , @( (Run 'Before you renew, check your exclusions and your excess.' 10 $Text $true $Font) )
) 'What less cover means. Exclusions: treatments a policy does not pay for at all. Reduced cover: treatments a policy pays only reduced benefits for. Excess: what you pay towards a hospital admission before the insurer pays. Since 1 April 2019 it can be up to 750 dollars for a single person, up from 500. Before you renew, check your exclusions and your excess.'

# ================================================================ page 3: an older pool
NewPage 'older_pool' 'An older pool'
$pg = 'older_pool'
AddFrame $pg ("3 OF 3 $Dot AN OLDER POOL") 'Is the pool getting older?' `
    'Yes. By June 2025, people aged 65 and over made up **20.7%** of the insured, up from **13.3%** in June 2007. Across Australia the share rose less, from **13.1%** to **17.4%**.' `
    "These figures are for Australia as a whole: APRA's population by age has no state breakdown. In June 2018 its population table lacks women aged 95+, so Australia's 65+ share is slightly understated that year."
AddKpi $pg 'kpi_insured_65'   24  400 'Insured people aged 65+' 'Share Aged 65+, Insured Label' 'Share Aged 65+, Insured' 'Share Aged 65+, Insured Context' $Orange 'Share of people with hospital cover who are aged 65 or over, in the latest June with population figures by age.'
AddKpi $pg 'kpi_australia_65' 440 400 'All Australians aged 65+' 'Share Aged 65+, Australia Label' 'Share Aged 65+, Australia' 'Share Aged 65+, Australia Context' $Grey 'Share of all Australians aged 65 or over, in the same June.'
AddKpi $pg 'kpi_gap'          856 400 'Gap, percentage points' 'Age Gap Label' 'Age Gap (points)' 'Age Gap Context' $Orange "How many percentage points the insured pool's 65+ share runs ahead of Australia's, in the same June."

AddVisual $pg 'share_65_by_june' 24 296 1232 236 (LineVisual @(
        # The two lines start 0.2 points apart: insured labels above their line, Australia's below.
        @{ Measure = 'Share Aged 65+, Insured'; Label = 'Insured people'; Color = $Orange; KeyLabel = 'Share Aged 65+, Insured Key Label'; NameColor = $Orange; LabelPosition = 'Above' },
        @{ Measure = 'Share Aged 65+, Australia'; Label = 'All Australians'; Color = $Grey; KeyLabel = 'Share Aged 65+, Australia Key Label'; NameColor = $Text2; LabelPosition = 'Under' }
    ) `
    'Insured people are ageing faster than Australia: aged 65+ rose from 13.3% to 20.7% of the insured, against 13.1% to 17.4% of everyone' `
    'Share of people aged 65 or over, each June: people with hospital cover against all Australians.' $false $null $null $true)

$ageBand = Col 'dim_age_band' 'age_band'
AddVisual $pg 'coverage_change_by_age' 24 548 1232 248 (ColumnVisual $ageBand 'Age' 'Coverage Change by Age (points)' 'Change, points' @(
        @{ Measure = 'Coverage by Age, First June'; Label = 'Coverage, June 2007' },
        @{ Measure = 'Coverage by Age, Latest June'; Label = 'Coverage, June 2025' }
    ) @("'25-29'", "'30-34'", "'50-54'", "'55-59'", "'60-64'", "'80-84'", "'85-89'") `
    'Coverage rose most among 80- to 89-year-olds, up 18 to 19 points since 2007, and fell among 25- to 34- and 50- to 64-year-olds' `
    'Change in the share of each age band with hospital cover, June 2007 to June 2025, percentage points. National figures.' $null $false)

# ================================================================ tab order, serialise and check, before writing
foreach ($name in $pages.Keys) {
    $vis = $pages[$name].Visuals
    $order = @($vis | Where-Object { -not $_.Decorative } | Sort-Object { $_.Json.position.y }, { $_.Json.position.x }) +
             @($vis | Where-Object { $_.Decorative } | Sort-Object { $_.Json.position.y }, { $_.Json.position.x })
    $n = 0
    foreach ($v in $order) { $n += 1000; $v.Json.position.tabOrder = $n }
}

$model = @{}
foreach ($f in Get-ChildItem -LiteralPath $TablesDir -Filter *.tmdl) {
    $lines = [IO.File]::ReadAllLines($f.FullName, $utf8)
    $table = (($lines | Where-Object { $_ -match '^table ' } | Select-Object -First 1) -replace '^table ', '') -replace "^'(.*)'$", '$1'
    $cols = @($lines | Where-Object { $_ -match "^`tcolumn " } | ForEach-Object { ($_ -replace "^`tcolumn ", '') -replace "^'(.*)'$", '$1' })
    $meas = @($lines | Where-Object { $_ -match "^`tmeasure " } | ForEach-Object { (($_ -replace "^`tmeasure ", '') -replace ' =.*$', '') -replace "^'(.*)'$", '$1' })
    $model[$table] = @{ Column = $cols; Measure = $meas }
}
function Walk($node, [hashtable]$aliases, $found) {
    if ($null -eq $node) { return }
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        $names = @($node.PSObject.Properties.Name)
        if ($names -contains 'From') { foreach ($f in @($node.From)) { $aliases[$f.Name] = $f.Entity } }
        foreach ($kind in 'Column', 'Measure') {
            if ($names -contains $kind) {
                $ref = $node.$kind
                $src = $ref.Expression.SourceRef
                $entity = if (@($src.PSObject.Properties.Name) -contains 'Entity') { $src.Entity } else { $aliases[$src.Source] }
                [void]$found.Add("$kind|$entity|$($ref.Property)")
            }
        }
        if ($names -contains 'metadata' -and $node.metadata -is [string]) {
            $i = $node.metadata.IndexOf('.')
            [void]$found.Add("Any|$($node.metadata.Substring(0, $i))|$($node.metadata.Substring($i + 1))")
        }
        foreach ($p in $node.PSObject.Properties) { Walk $p.Value $aliases $found }
    } elseif ($node -is [System.Array]) {
        foreach ($i in $node) { Walk $i $aliases $found }
    }
}

$files = [ordered]@{}
$pagesDir = Join-Path $ReportDir 'definition\pages'
foreach ($name in $pages.Keys) {
    $pageJson = [ordered]@{
        '$schema' = $pageSchema; name = $name; displayName = $pages[$name].Display; displayOption = 'FitToPage'
        height = $H; width = $W
        objects = [ordered]@{
            background = @( (P ([ordered]@{ color = (Fill $Page); transparency = (LD 0) })) )
            outspace   = @( (P ([ordered]@{ color = (Fill $Page); transparency = (LD 0) })) )
        }
    }
    $files[(Join-Path $pagesDir "$name\page.json")] = J $pageJson
    foreach ($v in $pages[$name].Visuals) {
        $files[(Join-Path $pagesDir "$name\visuals\$($v.Json.name)\visual.json")] = J $v.Json
    }
}
$files[(Join-Path $pagesDir 'pages.json')] = J ([ordered]@{ '$schema' = $pagesSchema; pageOrder = @($pages.Keys); activePageName = $ActivePage })

$found = New-Object System.Collections.Generic.HashSet[string]
foreach ($path in $files.Keys) {
    try { $parsed = $files[$path] | ConvertFrom-Json } catch { throw "Not valid JSON: $path ($($_.Exception.Message))" }
    Walk $parsed @{} $found
}
$missing = foreach ($r in $found) {
    $kind, $entity, $prop = $r -split '\|', 3
    if (-not $model.ContainsKey($entity)) { "$r (no table $entity)"; continue }
    $ok = switch ($kind) {
        'Column'  { $model[$entity].Column -ccontains $prop }
        'Measure' { $model[$entity].Measure -ccontains $prop }
        default   { ($model[$entity].Column -ccontains $prop) -or ($model[$entity].Measure -ccontains $prop) }
    }
    if (-not $ok) { $r }
}
if ($missing) { throw "Fields not in the model, nothing written:`n$($missing -join "`n")" }

# ================================================================ write: replace the three page folders
foreach ($name in $pages.Keys) {
    $dir = Join-Path $pagesDir $name
    if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse }
}
foreach ($path in $files.Keys) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($files[$path] -replace "`n", "`r`n"), $utf8)
}

"Wrote $($files.Count) files; $($found.Count) distinct field references, all in the model. Active page: $ActivePage."
foreach ($name in $pages.Keys) {
    "== $name ($($pages[$name].Display)): $($pages[$name].Visuals.Count) visuals"
}
