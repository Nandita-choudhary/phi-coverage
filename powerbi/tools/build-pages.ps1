param(
    [Parameter(Mandatory)][string]$ReportDir,
    [Parameter(Mandatory)][string]$TablesDir,
    [ValidateSet('headline', 'downgrading', 'older_pool')][string]$ActivePage = 'headline'
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Writes the report's three pages as PBIR files: the dark design of the section 7 briefs. Builds every
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
function MeaFill([string]$p) { [ordered]@{ solid = [ordered]@{ color = (MeaExpr $p) } } }
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

# ================================================================ design tokens (the briefs)
$Page = '#0B1220'; $Panel = '#131C2E'; $Line = '#24324A'; $Grid = '#2E3D58'; $Rule = '#334155'
$Text = '#F1F5F9'; $Text2 = '#94A3B8'; $NavText = '#CBD5E1'; $ZeroLine = '#94A3B8'
$Orange = '#EB6834'; $Blue = '#4C9BEF'; $Grey = '#64748B'
$AgeBlue1 = '#1E3A5F'; $AgeBlue2 = '#2C5C94'; $AgeBlue3 = '#3B82C4'
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
# Text that starts with '=' names a measure: the title, subtitle, alt text or text run takes its value from it.
function TV([string]$t) { if ($t.StartsWith('=')) { MeaExpr $t.Substring(1) } else { LStr $t } }
function AltText([string]$t) { P ([ordered]@{ altText = (TV $t) }) }
function ChartTitle([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (TV $t); fontFamily = (LStr $Semi); fontSize = (LD 12); bold = (LB $false)
                   fontColor = (Fill $Text); titleWrap = (LB $true) })
}
function ChartSub([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (TV $t); fontFamily = (LStr $Font); fontSize = (LD 9.5)
                   fontColor = (Fill $Text2); titleWrap = (LB $true) })
}
# A panel: #131C2E fill, 1 px #24324A border, radius 12, no shadow, 16 px padding.
function PanelObjects([string]$title, [string]$sub, [string]$alt) {
    [ordered]@{
        background   = @( (Bg $Panel) )
        border       = @( (Edge $Line 12) )
        dropShadow   = @( (Hidden) )
        padding      = @( (Pad4 $Pad $Pad $Pad $Pad) )
        title        = @( $(if ($title) { ChartTitle $title } else { Hidden }) )
        subTitle     = @( $(if ($sub) { ChartSub $sub } else { Hidden }) )
        visualHeader = @( (Hidden) )
        general      = @( (AltText $alt) )
    }
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
# What Power BI writes on save for a chart with a category axis: the category field marked active, schema 2.13.0.
$categorySchema = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.13.0/schema.json'
$pageSchema   = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
$pagesSchema  = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json'
$pages = [ordered]@{}
$script:z = 0

function NewPage([string]$name, [string]$display) {
    $pages[$name] = [ordered]@{ Display = $display; Visuals = (New-Object System.Collections.Generic.List[object]) }
    $script:z = 0
}
# Decorative visuals (panels, strips, the rule) are drawn behind and come last in the tab order. Visuals with
# the same $Group (a KPI tile, a donut) are read together, in the place of the group's top-left visual.
function AddVisual([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $visual, $filterConfig = $null, [switch]$Decorative, [string]$Group = '') {
    $script:z += 1000
    $schema = $visualSchema
    if ($visual.Contains('query') -and $visual.query.queryState.Contains('Category')) {
        $c = $visual.query.queryState.Category.projections[0]
        $visual.query.queryState.Category.projections[0] = [ordered]@{ field = $c.field; queryRef = $c.queryRef; nativeQueryRef = $c.nativeQueryRef; active = $true; displayName = $c.displayName }
        $schema = $categorySchema
    }
    $o = [ordered]@{
        '$schema' = $schema
        name      = $name
        position  = [ordered]@{ x = $x; y = $y; z = $script:z; height = $h; width = $w; tabOrder = 0 }
        visual    = $visual
    }
    if ($null -ne $filterConfig) { $o['filterConfig'] = $filterConfig }
    $pages[$page].Visuals.Add([pscustomobject]@{ Json = $o; Decorative = [bool]$Decorative; Group = $(if ($Group) { $Group } else { $name }) })
}

# ---- text
# A run of text; '=Measure' makes it a dynamic value, the measure's text.
function Run([string]$text, [double]$pt, [string]$color, [bool]$bold = $false, [string]$family = '') {
    $style = [ordered]@{}
    if ($family) { $style['fontFamily'] = $family }
    if ($bold) { $style['fontWeight'] = 'bold' }
    $style['fontSize'] = [string]$pt + 'pt'
    if ($color) { $style['color'] = $color }
    [ordered]@{ value = $(if ($text.StartsWith('=')) { MeaExpr $text.Substring(1) } else { $text }); textStyle = $style }
}
function Para($runs, [string]$align = '') {
    $o = [ordered]@{ textRuns = @($runs) }
    if ($align) { $o['horizontalTextAlignment'] = $align }
    $o
}
function Spacer([double]$pt) { Para @( (Run ' ' $pt '') ) }
function TextVisual($paragraphs, $containerObjects) {
    [ordered]@{
        visualType = 'textbox'
        objects = [ordered]@{ general = @( (P ([ordered]@{ paragraphs = @($paragraphs) })) ) }
        visualContainerObjects = $containerObjects
        drillFilterOtherVisuals = $true
    }
}
# A block of colour: panels and accent strips are text boxes with a fill.
function AddBlock([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, [string]$fill, [string]$border, [int]$radius) {
    $objs = FlatObjects $fill @(0, 0, 0, 0) 'Decorative'
    if ($border) { $objs['border'] = @( (Edge $border $radius) ) }
    AddVisual $page $name $x $y $w $h (TextVisual @( (Spacer 1) ) $objs) -Decorative
}
# A 1 px rule: a text box with no text at all, so it has nothing to scroll.
function AddRule([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [string]$fill) {
    $visual = [ordered]@{
        visualType = 'textbox'
        objects = [ordered]@{ general = @( (P ([ordered]@{ paragraphs = @() })) ) }
        visualContainerObjects = (FlatObjects $fill @(0, 0, 0, 0) 'Decorative rule')
        drillFilterOtherVisuals = $true
    }
    AddVisual $page $name $x $y $w 1 $visual -Decorative
}

# ---- the new card visual as a line of text driven by a measure
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
# Every number and date on the pages comes from a measure: the takeaway, footnote and source are dynamic text.
$Source = '=Footer Source'
# $footerShift moves the footnote, source and repository down (page 3 needs the room).
function AddFrame([string]$page, [string]$eyebrow, [string]$question, [string]$takeaway, [string]$footnote, [int]$footerShift = 0) {
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
                # Selected: slate with a light outline. Power BI draws the selected text in the theme's "background"
                # colour (light, see theme.json), so a light fill would hide it.
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $Rule); transparency = (LD 0) }) ([ordered]@{ id = 'selected' }))
            )
            text = @(
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $NavText); fontSize = (LD 10); fontFamily = (LStr $Font) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $Text); fontSize = (LD 10); fontFamily = (LStr $Semi) }) ([ordered]@{ id = 'selected' }))
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
    AddRule $page 'divider' $M 96 ($W - 2 * $M) $Rule
    AddVisual $page 'takeaway' $M 112 ($W - 2 * $M) 48 (TextVisual @( (Para @( (Run $takeaway 12 $Text $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $takeaway))

    # Footer: footnote, then the source with the repository right-aligned on its last line.
    if ($footnote) {
        AddVisual $page 'footnote' $M (808 + $footerShift) ($W - 2 * $M) 32 (TextVisual @( (Para @( (Run $footnote 8.5 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $footnote))
    }
    AddVisual $page 'source' $M (848 + $footerShift) 968 32 (TextVisual @( (Para @( (Run $Source 8.5 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $Source))
    AddVisual $page 'repository' 1008 (864 + $footerShift) 248 16 (TextVisual @( (Para @( (Run 'github.com/Nandita-choudhary/phi-coverage' 8.5 $Text2 $false $Font) ) 'right') ) (FlatObjects '' @(0, 0, 0, 0) 'github.com/Nandita-choudhary/phi-coverage'))
}

# ---- KPI tile: label on top, then the value, then a context line, with a 4 px accent strip
function AddKpi([string]$page, [string]$name, [int]$x, [int]$w, [string]$label, [string]$labelMeasure, [string]$valueMeasure, [string]$contextMeasure, [string]$strip, [string]$tip) {
    $y = 176; $h = 104
    AddBlock $page "${name}_panel" $x $y $w $h $Panel $Line 12
    AddBlock $page "${name}_strip" ($x + $Pad) ($y + $Pad) 4 ($h - 2 * $Pad) $strip $strip 2
    $tx = $x + $Pad + 16; $tw = $w - 2 * $Pad - 16
    if ($labelMeasure) {
        AddVisual $page "${name}_label" $tx ($y + 12) $tw 20 (CardText $labelMeasure 'Label' 10 $Text2 $Font 'left' $label) -Group $name
    } else {
        AddVisual $page "${name}_label" $tx ($y + 12) $tw 20 (TextVisual @( (Para @( (Run $label 10 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) $label)) -Group $name
    }
    AddVisual $page "${name}_value" $tx ($y + 30) $tw 46 (CardText $valueMeasure $label 26 $Text $Semi 'left' "$label. $tip" $tip) -Group $name
    AddVisual $page "${name}_context" $tx ($y + 76) $tw 20 (CardText $contextMeasure 'Context' 10 $Text2 $Font 'left' "Context for $label") -Group $name
}

# ---- text panel: heading, then paragraphs; each paragraph is a list of runs
# -tight: spacers only after the heading and before the last paragraph (a spacer is about 15 px whatever its size).
function AddTextPanel([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, [string]$heading, $paragraphs, [string]$alt, [switch]$tight) {
    $paras = @( (Para @( (Run $heading 12 $Text $false $Semi) )) )
    $n = 0
    foreach ($runs in $paragraphs) {
        $n++
        if (-not $tight -or $n -eq 1 -or $n -eq @($paragraphs).Count) { $paras += (Spacer 4) }
        $paras += (Para @($runs))
    }
    $objs = FlatObjects $Panel @($Pad, $Pad, $Pad, $Pad) $alt
    $objs['border'] = @( (Edge $Line 12) )
    AddVisual $page $name $x $y $w $h (TextVisual $paras $objs)
}

# ---- chart pieces
$Quarter = Col 'dim_date' 'quarter_end'
$Year = Col 'dim_date' 'year'
function CatAxis([bool]$scalar, [string]$labelColor = $Text2) {
    $p = [ordered]@{ show = (LB $true); labelColor = (Fill $labelColor); fontSize = (LD 9); fontFamily = (LStr $Font)
                     gridlineShow = (LB $false); showAxisTitle = (LB $false) }
    if ($scalar) { $p['axisType'] = (LStr 'Scalar') }
    P $p
}
function ValAxis($extra = $null) {
    $p = [ordered]@{ show = (LB $true); labelColor = (Fill $Text2); fontSize = (LD 9); fontFamily = (LStr $Font)
                     gridlineShow = (LB $true); gridlineColor = (Fill $Grid); showAxisTitle = (LB $false) }
    if ($extra) { foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] } }
    P $p
}
# Base data labels: 9 pt, with a panel-coloured background so no line runs through the text.
function BaseLabels([hashtable]$extra = @{}) {
    $p = [ordered]@{ show = (LB $true); color = (Fill $Text); fontSize = (LD 9); fontFamily = (LStr $Font)
                     enableBackground = (LB $true); backgroundColor = (Fill $Panel); backgroundTransparency = (LD 0) }
    foreach ($k in $extra.Keys) { $p[$k] = $extra[$k] }
    P $p
}
# Labels from a measure that is blank except at the points to label.
function KeyLabels([string]$measure, [string]$labelMeasure, [string]$position) {
    $series = [ordered]@{ showSeries = (LB $true); showDynamicLabels = (LB $true); color = (Fill $Text) }
    if ($position) { $series['labelPosition'] = (LStr $position) }
    @( (P $series (Meta $measure)),
       (P ([ordered]@{ showDynamicLabels = (LB $true); dynamicLabelValue = (MeaExpr $labelMeasure); showBlankAs = (LStr '') }) (EachPoint $measure)) )
}
# A solid 1 px zero line on the value axis, optionally labelled from a measure. Never dashed.
function ZeroLine([string]$labelMeasure = '') {
    $p = [ordered]@{ show = (LB $true); value = (L '0D'); lineColor = (Fill $ZeroLine); transparency = (LD 0)
                     style = (LStr 'solid'); width = (LD 1); position = (LStr 'front') }
    if ($labelMeasure) {
        $p['displayName'] = (MeaExpr $labelMeasure); $p['dataLabelShow'] = (LB $true); $p['dataLabelText'] = (LStr 'Name')
        $p['dataLabelColor'] = (Fill $Text2); $p['dataLabelHorizontalPosition'] = (LStr 'right'); $p['dataLabelVerticalPosition'] = (LStr 'above')
    } else { $p['dataLabelShow'] = (LB $false) }
    P $p ([ordered]@{ id = '0' })
}
function Filters($filters) { [ordered]@{ filters = @($filters) } }
function DateFrom([string]$name, [string]$display, [string]$iso) {
    [ordered]@{
        name = $name; displayName = $display; field = (Col 'dim_date' 'quarter_end'); type = 'Advanced'
        filter = [ordered]@{
            Version = 2
            From = @( [ordered]@{ Name = 'd'; Entity = 'dim_date'; Type = 0 } )
            Where = @( [ordered]@{ Condition = [ordered]@{ Comparison = [ordered]@{
                ComparisonKind = 2
                Left = [ordered]@{ Column = [ordered]@{ Expression = [ordered]@{ SourceRef = [ordered]@{ Source = 'd' } }; Property = 'quarter_end' } }
                Right = [ordered]@{ Literal = [ordered]@{ Value = "datetime'$iso'" } }
            } } } )
        }
    }
}
# Only the June quarters: their labels start with "Jun".
function JunesOnly {
    [ordered]@{
        name = 'junesOnly'; displayName = 'June quarters only'; field = (Col 'dim_date' 'quarter_label'); type = 'Advanced'
        filter = [ordered]@{
            Version = 2
            From = @( [ordered]@{ Name = 'd'; Entity = 'dim_date'; Type = 0 } )
            Where = @( [ordered]@{ Condition = [ordered]@{ StartsWith = [ordered]@{
                Left = [ordered]@{ Column = [ordered]@{ Expression = [ordered]@{ SourceRef = [ordered]@{ Source = 'd' } }; Property = 'quarter_label' } }
                Right = [ordered]@{ Literal = [ordered]@{ Value = "'Jun'" } }
            } } } )
        }
    }
}
# Line chart over quarters. Each series: Measure, Label, Color, KeyLabel, LabelPosition, NameColor.
# Alt text for a panel: its title (a measure when the title is one), with the subtitle when both are fixed text.
function AltFor([string]$title, [string]$sub) { if ($title.StartsWith('=') -or -not $sub) { $title } else { "$title. $sub" } }
# Line chart over quarters. Each series: Measure, Label, Color, KeyLabel, LabelPosition; Marker = $true draws
# the series as dots only (no line, no area), for a single marked point.
function LineVisual($series, [string]$title, [string]$sub, $valueExtra, [bool]$area) {
    $objects = [ordered]@{ categoryAxis = @( (CatAxis $true) ); valueAxis = @( (ValAxis $valueExtra) ); legend = @( (Hidden) ) }
    $objects['dataPoint'] = @( @($series) | ForEach-Object { P ([ordered]@{ fill = (Fill $_.Color) }) (Meta $_.Measure) } )
    $style = [ordered]@{ strokeWidth = (LD 2.5); showMarker = (LB $false) }
    if ($area) {
        # Shaded area under each line in the line's colour at 85% transparency ("Area transparency" lives in dataPoint).
        $style['areaShow'] = (LB $true); $style['areaMatchStrokeColor'] = (LB $true)
        $objects['dataPoint'] = @( (P ([ordered]@{ transparency = (LD 85) })) ) +
            @( @($series) | ForEach-Object { P ([ordered]@{ fill = (Fill $_.Color); transparency = (LD 85) }) (Meta $_.Measure) } )
    }
    $objects['lineStyles'] = @( (P $style) ) + @( @($series) | Where-Object { $_.Marker } | ForEach-Object {
        P ([ordered]@{ strokeShow = (LB $false); areaShow = (LB $false); showMarker = (LB $true); markerShape = (LStr 'circle')
                       markerSize = (LD 5); markerColor = (Fill $_.Color) }) (Meta $_.Measure) } )
    # A series without a KeyLabel shows no labels (a marker's label rides on the main line, so the two cannot collide).
    $labels = @( (BaseLabels @{ labelDensity = (LD 100) }) )
    foreach ($s in @($series)) {
        if ($s.KeyLabel) { $labels += (KeyLabels $s.Measure $s.KeyLabel $s.LabelPosition) }
        else { $labels += (P ([ordered]@{ showSeries = (LB $false) }) (Meta $s.Measure)) }
    }
    $objects['labels'] = $labels
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
        visualContainerObjects = (PanelObjects $title $sub (AltFor $title $sub))
        drillFilterOtherVisuals = $true
    }
}
# Diverging bars or columns: one measure, coloured by a colour measure, with a zero line.
# $narrow: many narrow columns, so 8 pt labels with no background (which would make neighbours collide)
# and no gridlines (so no line runs through a label); every column carries its value instead.
function DivergingVisual([string]$type, $category, [string]$categoryName, [string]$measure, [string]$measureName, [string]$colourMeasure, $tooltips, [string]$title, [string]$sub, [string]$zeroLabel, $sort, [string]$axisEndMeasure = '', [switch]$narrow) {
    # An axis end from a measure leaves room for the longest bar's label, whatever the data.
    $axisExtra = [ordered]@{}
    if ($axisEndMeasure) { $axisExtra['end'] = (MeaExpr $axisEndMeasure) }
    if ($narrow) { $axisExtra['gridlineShow'] = (LB $false) }
    $labelExtra = @{ labelPosition = (LStr 'OutsideEnd') }
    if ($narrow) { $labelExtra['fontSize'] = (LD 8); $labelExtra['enableBackground'] = (LB $false) }
    # Category names at 8 pt on narrow columns, so they fit level; Power BI angles them only if they don't.
    $catAxis = CatAxis $false $Text
    if ($narrow) { $catAxis.properties['fontSize'] = (LD 8) }
    $objects = [ordered]@{
        categoryAxis = @( $catAxis )
        valueAxis    = @( (ValAxis $axisExtra) )
        legend       = @( (Hidden) )
        # A colour measure on one series: the selector Power BI writes is the data wildcard alone.
        dataPoint    = @( (P ([ordered]@{ fill = (MeaFill $colourMeasure) }) ([ordered]@{ data = @( [ordered]@{ dataViewWildcard = [ordered]@{ matchingOption = 1 } } ) })) )
        labels       = @( (BaseLabels $labelExtra) )
        y1AxisReferenceLine = @( (ZeroLine $zeroLabel) )
    }
    $state = [ordered]@{
        Category = [ordered]@{ projections = @( (Proj $category $categoryName) ) }
        Y        = [ordered]@{ projections = @( (Proj (Mea $measure) $measureName) ) }
    }
    if ($tooltips) { $state['Tooltips'] = [ordered]@{ projections = @( $tooltips | ForEach-Object { Proj (Mea $_.Measure) $_.Label } ) } }
    [ordered]@{
        visualType = $type
        query = [ordered]@{ queryState = $state; sortDefinition = $sort }
        objects = $objects
        visualContainerObjects = (PanelObjects $title $sub (AltFor $title $sub))
        drillFilterOtherVisuals = $true
    }
}

# ================================================================ page 1: the headline
NewPage 'headline' 'The headline'
$pg = 'headline'
AddFrame $pg ("1 OF 3 $Dot THE HEADLINE") "Membership is at a record. Isn't everything fine?" '=Takeaway, Headline' ''
AddKpi $pg 'kpi_insured'  24  296 'People with hospital cover' 'Insured Persons Label' 'Insured Persons' 'Insured Persons Context' $Blue 'People with private hospital cover at the end of the latest quarter, Australia-wide.'
AddKpi $pg 'kpi_change'   336 296 'Change on a year earlier' 'Insured Persons Change Label' 'Insured Persons, Change on a Year Earlier' 'Insured Persons Change Context' $Blue 'People with hospital cover, against the same quarter a year earlier.'
AddKpi $pg 'kpi_coverage' 648 296 'Share of Australians covered' 'Coverage Rate Label' 'Coverage Rate' 'Coverage Rate Context' $Orange "People with hospital cover as a share of Australia's population, at the end of the latest quarter."
AddKpi $pg 'kpi_policies' 960 296 'Hospital policies' 'Hospital Policies Label' 'Hospital Policies' 'Hospital Policies Context' $Grey 'Hospital policies at the end of the latest quarter. One policy can cover several people.'

# Combo: a column for each June (people, left axis, millions) and the coverage line (right axis, from measures:
# 5 points either side of the June rates). The low label sits under the line, so it rides on an invisible copy
# of the line with its labels below.
$comboTitle = '=Title, Members and Coverage'
$comboSub = '=Subtitle, Members and Coverage'
$combo = [ordered]@{
    visualType = 'lineClusteredColumnComboChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj $Year 'June') ) }
            Y  = [ordered]@{ projections = @( (Proj (Mea 'Insured Persons') 'People with hospital cover') ) }
            Y2 = [ordered]@{ projections = @( (Proj (Mea 'Coverage Rate') 'Share of Australians covered'), (Proj (Mea 'Coverage Rate, Line for Labels Below') 'Share covered (labels below)') ) }
        }
        sortDefinition = (SortBy $Year 'Ascending')
    }
    objects = [ordered]@{
        categoryAxis = @( (CatAxis $false) )
        # The left axis top keeps the column tops (and their label slots) below the peak label.
        valueAxis = @( (ValAxis ([ordered]@{
            start = (LD 0); end = (MeaExpr 'Insured Persons, Axis Max'); labelDisplayUnits = (LD 1000000); labelPrecision = (LL 0)
            showAxisTitle = (LB $true); titleText = (LStr 'People with hospital cover'); titleColor = (Fill $Text2); titleFontSize = (LD 9)
            secShow = (LB $true); secStart = (MeaExpr 'Coverage Rate, Axis Min'); secEnd = (MeaExpr 'Coverage Rate, Axis Max'); secLabelColor = (Fill $Text2); secFontSize = (LD 9); secLabelPrecision = (LL 0)
            secShowAxisTitle = (LB $true); secTitleText = (LStr 'Share of Australians covered'); secTitleColor = (Fill $Text2); secTitleFontSize = (LD 9)
        })) )
        legend = @( (Hidden) )
        # A single column series takes the default colour, not its series entry.
        dataPoint = @(
            (P ([ordered]@{ defaultColor = (Fill $Blue) })),
            (P ([ordered]@{ fill = (Fill $Blue) }) (Meta 'Insured Persons')),
            (P ([ordered]@{ fill = (Fill $Orange) }) (Meta 'Coverage Rate')),
            (P ([ordered]@{ fill = (Fill $Orange) }) (Meta 'Coverage Rate, Line for Labels Below'))
        )
        lineStyles = @(
            (P ([ordered]@{ strokeWidth = (LD 2.5); showMarker = (LB $false) })),
            (P ([ordered]@{ strokeShow = (LB $false); showMarker = (LB $false) }) (Meta 'Coverage Rate, Line for Labels Below'))
        )
        # The latest June's label sits under the line: above it, it would collide with 12.8M and be hidden.
        labels = @( (BaseLabels @{ labelDensity = (LD 100) }) ) + (KeyLabels 'Insured Persons' 'Insured Persons, June Key Label' 'OutsideEnd') +
                 (KeyLabels 'Coverage Rate' 'Coverage Rate, June Label Above' 'Above') + (KeyLabels 'Coverage Rate, Line for Labels Below' 'Coverage Rate, June Label Below' 'Under')
        y1AxisReferenceLine = @( (ZeroLine) )
    }
    visualContainerObjects = (PanelObjects $comboTitle $comboSub (AltFor $comboTitle $comboSub))
    drillFilterOtherVisuals = $true
}
# 856 wide so the title fits on one line, which leaves the right axis title room to show in full.
AddVisual $pg 'members_and_coverage' 24 296 856 296 $combo (Filters @( (JunesOnly) ))

# Two donuts: the covered slice orange, the rest #334155, a wide hole; the share and people in each hole.
# The donut's own centre value and slice borders are off; the hole text is two cards laid over it. Captions and
# donuts sit 12 px lower than the two-line heading needed, as the computed heading can run to three lines.
AddTextPanel $pg 'donut_panel' 896 296 360 296 '=Title, Donuts' @() '=Title, Donuts'
foreach ($d in @(@{ Tag = 'First'; X = 908 }, @{ Tag = 'Latest'; X = 1072 })) {
    $donut = [ordered]@{
        visualType = 'donutChart'
        query = [ordered]@{ queryState = [ordered]@{ Y = [ordered]@{ projections = @(
            (Proj (Mea "Covered, $($d.Tag) Quarter") 'Covered'), (Proj (Mea "Not Covered, $($d.Tag) Quarter") 'Not covered') ) } } }
        objects = [ordered]@{
            dataPoint = @(
                (P ([ordered]@{ borderShow = (LB $false) })),
                (P ([ordered]@{ fill = (Fill $Orange) }) (Meta "Covered, $($d.Tag) Quarter")),
                (P ([ordered]@{ fill = (Fill $Rule) }) (Meta "Not Covered, $($d.Tag) Quarter"))
            )
            legend = @( (Hidden) )
            labels = @( (Hidden) )
            centerValue = @( (Hidden) )
            slices = @( (P ([ordered]@{ innerRadiusRatio = (LD 80) })) )
        }
        visualContainerObjects = (FlatObjects '' @(0, 0, 0, 0) "Donut: share of Australians with hospital cover, $($d.Tag.ToLower()) quarter")
        drillFilterOtherVisuals = $true
    }
    $lower = $d.Tag.ToLower()
    AddVisual $pg "donut_${lower}_caption" $d.X 394 168 20 (CardText "Quarter Label, $($d.Tag)" 'Quarter' 10 $Text2 $Font 'center' "Donut caption, $lower quarter") -Group "donut_$lower"
    AddVisual $pg "donut_$lower" $d.X 402 168 176 $donut -Group "donut_$lower"
    AddVisual $pg "donut_${lower}_share" ($d.X + 14) 462 140 34 (CardText "Coverage Share Label, $($d.Tag) Quarter" 'Share covered' 24 $Text $Semi 'center' "Share covered, $lower quarter") -Group "donut_$lower"
    AddVisual $pg "donut_${lower}_people" ($d.X + 4) 498 160 18 (CardText "Coverage People Label, $($d.Tag) Quarter" 'People' 10 $Text2 $Font 'center' "People covered of all Australians, $lower quarter") -Group "donut_$lower"
}

AddTextPanel $pg 'how_numbers_work' 24 608 480 232 'How the numbers work' @(
    , @( (Run "Coverage is people with hospital cover divided by Australia's population." 10 $Text2 $false $Font) )
    , @( (Run "People, policies and population are counted at the end of each quarter, so a period's figure is its latest quarter, never a sum." 10 $Text2 $false $Font) )
    , @( (Run '=Text, Reconciliation Note' 10 $Text2 $false $Font) )
) "How the numbers work: what coverage means, how quarters are counted, and how the figures were checked against published ones."

$recon = @(
    @{ Field = (Col 'reconciliation_panel' 'measure'); Label = 'Measure'; Width = 380 },
    @{ Field = (Col 'reconciliation_panel' 'published_display'); Label = 'Published'; Width = 75 },
    @{ Field = (Col 'reconciliation_panel' 'ours_display'); Label = 'Rebuilt'; Width = 75 },
    @{ Field = (Mea 'Reconciliation Source'); Label = 'Source'; Width = 70 },
    @{ Field = (Mea 'Reconciliation Match'); Label = 'Match'; Width = 60 }
)
$tableTitle = '=Title, Reconciliation'
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
                                   gridHorizontalWeight = (LD 1); outlineColor = (Fill $Line); rowPadding = (LD 3) })) )
        columnWidth = @( $recon | ForEach-Object { P ([ordered]@{ value = (LD $_.Width) }) ([ordered]@{ metadata = (Proj $_.Field '').queryRef }) } )
    }
    visualContainerObjects = (PanelObjects $tableTitle '' $tableTitle)
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'reconciliation' 520 608 736 232 $table

# ================================================================ page 2: downgrading
NewPage 'downgrading' 'Downgrading'
$pg = 'downgrading'
AddFrame $pg ("2 OF 3 $Dot DOWNGRADING") 'Are people downgrading instead of leaving?' '=Takeaway, Downgrading' '=Footnote, Downgrading'
AddKpi $pg 'kpi_policies'   24  400 'Hospital policies' 'Hospital Policies Label' 'Hospital Policies' 'Hospital Policies Context' $Blue 'Hospital policies at the end of the latest quarter. One policy can cover several people.'
AddKpi $pg 'kpi_full_cover' 440 400 'With full cover' 'Full Cover Share Label' 'Full Cover Share' 'Full Cover Share Context' $Orange 'Share of hospital policies with full cover: no reduced cover and no lifetime exclusions. Latest quarter.'
AddKpi $pg 'kpi_excess'     856 400 'With an excess over 500 dollars' 'Excess Over 500 Share Label' 'Excess Over 500 Share' 'Excess Over 500 Share Context' $Orange 'Share of hospital policies with an excess over 500 dollars for a single person. Latest quarter.'

# Left column: the two trends. Right column: the state bars (eight bars need about 320 px) over the panel.
# The full cover chart marks the April 2019 reforms with a labelled dot at the first quarter end after them:
# no shading and no line, as the series was not broken by the reforms.
AddVisual $pg 'full_cover_by_quarter' 24 296 608 232 (LineVisual @(
        @{ Measure = 'Full Cover Share'; Label = 'With full cover'; Color = $Orange; KeyLabel = 'Full Cover Share, Chart Label'; LabelPosition = 'Above' },
        @{ Measure = 'Full Cover Share, April 2019 Reforms'; Label = 'April 2019 reforms'; Color = $Orange; Marker = $true }
    ) `
    '=Title, Full Cover' 'Share of hospital policies with full cover, at the end of each quarter.' ([ordered]@{ start = (LD 0); end = (MeaExpr 'Full Cover Share, Axis Max') }) $true)

# Two areas that share the March 2019 point: grey before the 1 April 2019 rule change, orange after, so the
# change of colour marks the rule change. 0.5% labels the grey part's last point, 29.4% the orange part's.
AddVisual $pg 'excess_by_quarter' 24 544 608 248 (LineVisual @(
        @{ Measure = 'Excess Over 500 Share, Before Rule Change'; Label = 'Before the rule change'; Color = $Grey; KeyLabel = 'Excess Over 500 Share Key Label'; LabelPosition = 'Above' },
        @{ Measure = 'Excess Over 500 Share, After Rule Change'; Label = 'After the rule change'; Color = $Orange; KeyLabel = 'Excess Over 500 Share, Latest Label'; LabelPosition = 'Above' }
    ) `
    '=Title, Excess' 'Share of hospital policies with an excess over 500 dollars (single), from September 2010.' ([ordered]@{ start = (LD 0); end = (MeaExpr 'Excess Over 500 Share, Axis Max') }) $true) (Filters @( (DateFrom 'fromSep2010' 'From September 2010' '2010-09-30T00:00:00') ))
# The note sits above the orange part, at its left end (the orange part starts near x 362), between the 40% and
# 20% gridlines (near y 655 and 700). The axis top at 1.5 times the highest share keeps the line below it;
# 200 wide keeps it clear of the 29.4% label.
AddVisual $pg 'excess_rule_note' 368 659 200 40 (TextVisual @( (Para @( (Run 'From 1 April 2019 the maximum excess rose to 750 dollars single' 9 $Text2 $false $Font) )) ) (FlatObjects '' @(0, 0, 0, 0) 'From 1 April 2019 the maximum excess rose to 750 dollars single')) -Group 'excess_by_quarter'

$gap = 'Full Cover Share, Gap to Australia (points)'
AddVisual $pg 'full_cover_gap_by_state' 648 296 608 320 (DivergingVisual 'clusteredBarChart' (Col 'dim_state' 'state_label') 'State' $gap 'Gap to Australia' 'Full Cover Share, Gap Colour' $null `
    '=Title, State Gap' 'Share of hospital policies with full cover, latest quarter, each state against Australia as a whole.' 'Full Cover Share, Australia Label' (SortBy (Mea $gap) 'Ascending'))

AddTextPanel $pg 'less_cover_means' 648 632 608 160 'What less cover means' @(
    , @( (Run 'Exclusions: ' 10 $Text $false $Semi), (Run 'treatments a policy does not pay for at all.' 10 $Text2 $false $Font) )
    , @( (Run 'Reduced cover: ' 10 $Text $false $Semi), (Run 'treatments a policy pays only reduced benefits for.' 10 $Text2 $false $Font) )
    , @( (Run 'Excess: ' 10 $Text $false $Semi), (Run 'what you pay towards a hospital admission before the insurer pays.' 10 $Text2 $false $Font) )
    , @( (Run 'Before you renew, check your exclusions and your excess.' 10 $Text $true $Font) )
) 'What less cover means. Exclusions: treatments a policy does not pay for at all. Reduced cover: treatments a policy pays only reduced benefits for. Excess: what you pay towards a hospital admission before the insurer pays. Before you renew, check your exclusions and your excess.' -tight

# ================================================================ page 3: an older pool
NewPage 'older_pool' 'An older pool'
$pg = 'older_pool'
AddFrame $pg ("3 OF 3 $Dot AN OLDER POOL") 'Is the pool getting older?' '=Takeaway, Older Pool' '=Footnote, Older Pool' 16
AddKpi $pg 'kpi_insured_65'   24  400 'Insured people aged 65+' 'Share Aged 65+, Insured Label' 'Share Aged 65+, Insured' 'Share Aged 65+, Insured Context' $Orange 'Share of people with hospital cover who are aged 65 or over, in the latest June with population figures by age.'
AddKpi $pg 'kpi_australia_65' 440 400 'All Australians aged 65+' 'Share Aged 65+, Australia Label' 'Share Aged 65+, Australia' 'Share Aged 65+, Australia Context' $Grey 'Share of all Australians aged 65 or over, in the same June.'
AddKpi $pg 'kpi_gap'          856 400 'Gap, percentage points' 'Age Gap Label' 'Age Gap (points)' 'Age Gap Context' $Orange "How many percentage points the insured pool's 65+ share runs ahead of Australia's, in the same June."

# Page 3 fits three charts under the tiles with 8 px gaps (16 elsewhere) and its footer 16 px lower.

# 65+ combo: the two shares as lines on the left axis, the gap between them as columns on the right axis, both
# ranges from measures. Power BI puts columns on the primary axis; switchAxisPosition moves it to the right.
$ageTitle = '=Title, Ageing'
$ageSub = 'Share of people aged 65 or over, each June (lines, left axis), and the gap between them in percentage points (columns, right axis).'
$gapSeries = 'Age Gap (points)'
$ageLines = @(
    # The two lines start 0.2 points apart: insured labels above their line, Australia's first label below.
    @{ Measure = 'Share Aged 65+, Insured'; Label = 'Insured people'; Color = $Orange; KeyLabel = 'Share Aged 65+, Insured Key Label'; NameColor = $Orange; LabelPosition = 'Above' },
    @{ Measure = 'Share Aged 65+, Australia'; Label = 'All Australians'; Color = $Grey; KeyLabel = 'Share Aged 65+, Australia, First Label'; NameColor = $Text2; LabelPosition = 'Under' }
)
# Australia's latest label sits above its line (below, it would touch the last column): it rides on a hidden
# copy of that one point, labelled above.
$ageCarrier = 'Share Aged 65+, Australia, Latest Point'
$ageLabels = @( (BaseLabels @{ labelDensity = (LD 100) }) )
foreach ($s in $ageLines) { $ageLabels += (KeyLabels $s.Measure $s.KeyLabel $s.LabelPosition) }
$ageLabels += (KeyLabels $ageCarrier 'Share Aged 65+, Australia Key Label' 'Above')
# The gap label (latest June only) sits inside its column.
$ageLabels += (KeyLabels $gapSeries 'Age Gap Key Label' 'InsideEnd')
# Names at the line ends, with no leader lines; none for the columns or the hidden point.
$ageNames = @( (P ([ordered]@{ show = (LB $true); textSize = (LD 9); seriesFontFamily = (LStr $Font); enableBackground = (LB $false)
                                seriesMatchColor = (LB $false); seriesColor = (Fill $Text2); leaderLines = (LB $false) })) )
foreach ($s in $ageLines) { $ageNames += (P ([ordered]@{ seriesMatchColor = (LB $false); seriesColor = (Fill $s.NameColor) }) (Meta $s.Measure)) }
$ageNames += (P ([ordered]@{ show = (LB $false) }) (Meta $gapSeries))
$ageNames += (P ([ordered]@{ show = (LB $false) }) (Meta $ageCarrier))
# Narrow gaps between the columns, so the latest one is wide enough to hold its label inside.
$ageAxis = CatAxis $false
$ageAxis.properties['innerPadding'] = (LL 20)
$ageCombo = [ordered]@{
    visualType = 'lineClusteredColumnComboChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj $Year 'June') ) }
            Y  = [ordered]@{ projections = @( (Proj (Mea $gapSeries) 'Gap, percentage points') ) }
            Y2 = [ordered]@{ projections = @( $ageLines | ForEach-Object { Proj (Mea $_.Measure) $_.Label } ) + @( (Proj (Mea $ageCarrier) 'All Australians, latest June') ) }
        }
        sortDefinition = (SortBy $Year 'Ascending')
    }
    objects = [ordered]@{
        categoryAxis = @( $ageAxis )
        # 8 pt axis title, so it fits the plot height in full.
        valueAxis = @( (ValAxis ([ordered]@{
            start = (LD 0); end = (MeaExpr 'Age Gap, Axis Max'); switchAxisPosition = (LB $true)
            showAxisTitle = (LB $true); titleText = (LStr 'Gap, percentage points'); titleColor = (Fill $Text2); titleFontSize = (LD 8)
            secShow = (LB $true); secStart = (MeaExpr 'Share Aged 65+, Axis Min'); secEnd = (MeaExpr 'Share Aged 65+, Axis Max'); secLabelColor = (Fill $Text2); secFontSize = (LD 9); secLabelPrecision = (LL 0)
            secShowAxisTitle = (LB $false)
        })) )
        legend = @( (Hidden) )
        # One column series takes the default colour; orange at 50% transparency.
        dataPoint = @(
            (P ([ordered]@{ defaultColor = (Fill $Orange); fillTransparency = (LD 50) })),
            (P ([ordered]@{ fill = (Fill $Orange); fillTransparency = (LD 50) }) (Meta $gapSeries))
        ) + @( $ageLines | ForEach-Object { P ([ordered]@{ fill = (Fill $_.Color) }) (Meta $_.Measure) } ) + @( (P ([ordered]@{ fill = (Fill $Grey) }) (Meta $ageCarrier)) )
        lineStyles = @(
            (P ([ordered]@{ strokeWidth = (LD 2.5); showMarker = (LB $false) })),
            (P ([ordered]@{ strokeShow = (LB $false); showMarker = (LB $false) }) (Meta $ageCarrier))
        )
        labels = $ageLabels
        seriesLabels = $ageNames
        y1AxisReferenceLine = @( (ZeroLine) )
    }
    visualContainerObjects = (PanelObjects $ageTitle $ageSub (AltFor $ageTitle $ageSub))
    drillFilterOtherVisuals = $true
}
# 252 tall: about 130 px of plot, enough for the right axis title in full and for 13.1% to clear the baseline.
AddVisual $pg 'share_65_by_june' 24 288 1232 252 $ageCombo (Filters @( (JunesOnly) ))

# Age mix: four 100% bars (insured and all Australians, first and latest June), four age groups.
$group = Col 'dim_age_band' 'age_group4'
$mixTitle = '=Title, Age Mix'
$mixSub = '=Subtitle, Age Mix'
# Little space between the four bars, so each is thick enough to hold its labels.
$mixAxis = CatAxis $false $Text
$mixAxis.properties['innerPadding'] = (LL 10)
$mix = [ordered]@{
    visualType = 'hundredPercentStackedBarChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj (Col 'mix_bars' 'bar') 'Group') ) }
            Series   = [ordered]@{ projections = @( (Proj $group 'Age group') ) }
            Y        = [ordered]@{ projections = @( (Proj (Mea 'Age Mix Share') 'Share') ) }
        }
        sortDefinition = (SortBy (Col 'mix_bars' 'bar') 'Ascending')
    }
    objects = [ordered]@{
        categoryAxis = @( $mixAxis )
        # No 0%/50%/100% labels: every segment carries its share, and the chart needs the height.
        valueAxis = @( (ValAxis ([ordered]@{ show = (LB $false) })) )
        legend = @( (P ([ordered]@{ show = (LB $true); position = (LStr 'Top'); showTitle = (LB $false); labelColor = (Fill $Text2); fontSize = (LD 9) })) )
        # A blue ramp that gets lighter with age, 65 and over in orange; a 1 px panel-coloured border between segments.
        dataPoint = @(
            (P ([ordered]@{ borderShow = (LB $true); borderColor = (Fill $Panel); borderSize = (LD 1) })),
            (P ([ordered]@{ fill = (Fill $AgeBlue1) }) (ScopeEq $group "'Under 25'")),
            (P ([ordered]@{ fill = (Fill $AgeBlue2) }) (ScopeEq $group "'25${EnDash}49'")),
            (P ([ordered]@{ fill = (Fill $AgeBlue3) }) (ScopeEq $group "'50${EnDash}64'")),
            (P ([ordered]@{ fill = (Fill $Orange) }) (ScopeEq $group "'65 and over'"))
        )
        # Power BI ignores the colour of labels inside stacked segments (visual, series or measure) and draws
        # them in the theme's "background" colour. That is why theme.json sets "background" light. Semibold, as
        # the lightest blue carries them at about 3.8:1.
        labels = @( (P ([ordered]@{ show = (LB $true); labelPosition = (LStr 'InsideCenter'); color = (Fill $Text); fontSize = (LD 9); fontFamily = (LStr $Semi)
                                     labelPrecision = (LL 1) })) )
        y1AxisReferenceLine = @( (ZeroLine) )
    }
    visualContainerObjects = (PanelObjects $mixTitle $mixSub (AltFor $mixTitle $mixSub))
    drillFilterOtherVisuals = $true
}
# 520 wide, so the smallest segment (13.1%) has room for its label.
AddVisual $pg 'age_mix' 24 548 520 264 $mix

# Change by age: twenty bands as diverging columns. Horizontal bars would need 20 px per band, over 400 px
# of plot, more than the page has.
AddVisual $pg 'coverage_change_by_age' 560 548 696 264 (DivergingVisual 'clusteredColumnChart' (Col 'dim_age_band' 'age_band') 'Age' 'Coverage Change by Age (points)' 'Change, points' 'Coverage Change by Age, Colour' @(
        # Tooltip names without dates: a display name cannot come from a measure.
        @{ Measure = 'Coverage by Age, First June'; Label = 'Coverage, first June' },
        @{ Measure = 'Coverage by Age, Latest June'; Label = 'Coverage, latest June' }
    ) '=Title, Change by Age' '=Subtitle, Change by Age' '' (SortBy (Col 'dim_age_band' 'age_band') 'Ascending') 'Coverage Change by Age, Axis Max' -narrow)

# ================================================================ tab order, serialise and check, before writing
# Left to right, top to bottom: each group (a KPI tile, a donut) at its top-left visual, then within the group.
foreach ($name in $pages.Keys) {
    $vis = $pages[$name].Visuals
    $anchor = @{}
    foreach ($g in ($vis | Group-Object Group)) {
        $top = $g.Group | Sort-Object { $_.Json.position.y }, { $_.Json.position.x } | Select-Object -First 1
        $anchor[$g.Name] = @($top.Json.position.y, $top.Json.position.x)
    }
    $order = @($vis | Where-Object { -not $_.Decorative } | Sort-Object { $anchor[$_.Group][0] }, { $anchor[$_.Group][1] }, { $_.Json.position.y }, { $_.Json.position.x }) +
             @($vis | Where-Object { $_.Decorative } | Sort-Object { $_.Json.position.y }, { $_.Json.position.x })
    $n = 0
    foreach ($v in $order) { $n += 1000; $v.Json.position.tabOrder = $n }
}

$model = @{}
foreach ($f in Get-ChildItem -LiteralPath $TablesDir -Filter *.tmdl) {
    $lines = [IO.File]::ReadAllLines($f.FullName, $utf8)
    $table = (($lines | Where-Object { $_ -match '^table ' } | Select-Object -First 1) -replace '^table ', '') -replace "^'(.*)'$", '$1'
    $cols = @($lines | Where-Object { $_ -match "^`tcolumn " } | ForEach-Object { (($_ -replace "^`tcolumn ", '') -replace ' =.*$', '') -replace "^'(.*)'$", '$1' })
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
    # Power BI rejects a formatting object that is not a list ("not provided as the correct type").
    foreach ($bag in 'objects', 'visualContainerObjects') {
        $o = if ($parsed.visual) { $parsed.visual.$bag } else { $null }
        if ($o) { foreach ($prop in $o.PSObject.Properties) { if ($prop.Value -isnot [System.Array]) { throw "$bag.$($prop.Name) is not a list in $path; nothing written" } } }
    }
    # Every visual carries alt text, fixed or from a measure.
    if ($parsed.visual -and -not ($parsed.visual.visualContainerObjects.general | Where-Object { $_.properties.altText })) { throw "No alt text in $path; nothing written" }
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
