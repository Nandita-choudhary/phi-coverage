param(
    [Parameter(Mandatory)][string]$ReportDir,
    [Parameter(Mandatory)][string]$TablesDir
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Guide section 7: three pages, in project 1's PBIR patterns. Builds everything in memory, checks
# every file parses and every field exists in the model, and only then writes.

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
function LD([int]$n) { L ("$n" + 'D') }
function Fill([string]$hex) { [ordered]@{ solid = [ordered]@{ color = (LStr $hex) } } }
function P($props, $selector = $null) {
    $o = [ordered]@{ properties = $props }
    if ($null -ne $selector) { $o['selector'] = $selector }
    $o
}
function Src([string]$e) { [ordered]@{ SourceRef = [ordered]@{ Entity = $e } } }
function Col([string]$e, [string]$p) { [ordered]@{ Column = [ordered]@{ Expression = (Src $e); Property = $p } } }
function Mea([string]$p) { [ordered]@{ Measure = [ordered]@{ Expression = (Src '_Measures'); Property = $p } } }
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

# ================================================================ colours (guide section 5, project 1)
$Ink = '#0B0B0B'; $Muted = '#52514E'; $White = '#FFFFFF'; $Grid = '#ECEBE6'; $PageBg = '#F4F3EF'
$Blue = '#2A78D6'; $Orange = '#EB6834'; $Grey = '#9E9C95'; $Navy = '#0D366B'; $Light = '#C8D2DE'

# ================================================================ container pieces
function Bg([string]$hex) {
    if ($hex) { P ([ordered]@{ show = (LB $true); color = (Fill $hex); transparency = (LD 0) }) }
    else { P ([ordered]@{ show = (LB $false) }) }
}
function Pad([int]$t, [int]$b, [int]$l, [int]$r) { P ([ordered]@{ top = (LD $t); bottom = (LD $b); left = (LD $l); right = (LD $r) }) }
function Edge([string]$hex, [int]$radius) { P ([ordered]@{ show = (LB $true); color = (Fill $hex); radius = (LD $radius); width = (LD 1) }) }
function Shadow {
    P ([ordered]@{ show = (LB $true); preset = (LStr 'Custom'); position = (LStr 'Outer'); color = (Fill '#000000')
                   transparency = (LD 84); shadowBlur = (LD 12); shadowSpread = (LD 0); shadowDistance = (LD 3); angle = (LD 90) })
}
function Hidden { P ([ordered]@{ show = (LB $false) }) }
function AltText([string]$t) { P ([ordered]@{ altText = (LStr $t) }) }
function ChartTitle([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (LStr $t); fontSize = (LD 13); bold = (LB $true); fontColor = (Fill $Ink); titleWrap = (LB $true) })
}
function ChartSub([string]$t) {
    P ([ordered]@{ show = (LB $true); text = (LStr $t); fontSize = (LD 10); fontColor = (Fill $Muted); titleWrap = (LB $true) })
}
function PanelObjects([string]$title, [string]$sub) {
    [ordered]@{
        background  = @( (Bg $White) )
        border      = @( (Edge $White 10) )
        dropShadow  = @( (Shadow) )
        padding     = @( (Pad 10 10 14 14) )
        title       = @( (ChartTitle $title) )
        subTitle    = @( (ChartSub $sub) )
        general     = @( (AltText "$title. $sub") )
    }
}
function FlatObjects([string]$bgHex, [int[]]$pad, [string]$alt) {
    [ordered]@{
        background = @( (Bg $bgHex) )
        padding    = @( (Pad $pad[0] $pad[1] $pad[2] $pad[3]) )
        title      = @( (Hidden) )
        subTitle   = @( (Hidden) )
        general    = @( (AltText $alt) )
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
function AddVisual([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $visual, $filterConfig = $null) {
    $script:z += 1000
    $o = [ordered]@{
        '$schema' = $visualSchema
        name      = $name
        position  = [ordered]@{ x = $x; y = $y; z = $script:z; height = $h; width = $w; tabOrder = $script:z }
        visual    = $visual
    }
    if ($null -ne $filterConfig) { $o['filterConfig'] = $filterConfig }
    $pages[$page].Visuals.Add($o)
}

# ---- text boxes
function Run([string]$text, [int]$pt, [string]$color, [bool]$bold) {
    $style = [ordered]@{}
    if ($bold) { $style['fontWeight'] = 'bold' }
    $style['fontSize'] = "${pt}pt"
    if ($color) { $style['color'] = $color }
    [ordered]@{ value = $text; textStyle = $style }
}
function Para([string]$text, [int]$pt, [string]$color = '', [bool]$bold = $false, [string]$align = '') {
    $o = [ordered]@{ textRuns = @( (Run $text $pt $color $bold) ) }
    if ($align) { $o['horizontalTextAlignment'] = $align }
    $o
}
function Spacer([int]$pt) { Para ' ' $pt }
function TextVisual($paragraphs, $containerObjects) {
    [ordered]@{
        visualType = 'textbox'
        objects = [ordered]@{ general = @( (P ([ordered]@{ paragraphs = @($paragraphs) })) ) }
        visualContainerObjects = $containerObjects
        drillFilterOtherVisuals = $true
    }
}
function AddStrip([string]$page, [string]$name, [int]$x, [int]$y, [int]$h, [string]$hex) {
    $objs = [ordered]@{
        background = @( (Bg $hex) )
        padding    = @( (Pad 0 0 0 0) )
        title      = @( (Hidden) )
        subTitle   = @( (Hidden) )
        border     = @( (Edge $hex 3) )
        general    = @( (AltText 'Decorative accent strip') )
    }
    AddVisual $page $name $x $y 5 $h (TextVisual @( (Spacer 1) ) $objs)
}
function AddNote([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $paragraphs, [string]$alt, [string]$strip) {
    $objs = [ordered]@{
        background = @( (Bg $White) )
        border     = @( (Edge $White 10) )
        dropShadow = @( (Shadow) )
        padding    = @( (Pad 14 12 30 16) )
        title      = @( (Hidden) )
        subTitle   = @( (Hidden) )
        general    = @( (AltText $alt) )
    }
    AddVisual $page $name $x $y $w $h (TextVisual $paragraphs $objs)
    AddStrip $page "${name}_strip" ($x + 10) ($y + 16) ($h - 32) $strip
}

# ---- header: band, page name and question, navigator, data period
function AddHeader([string]$page, [string]$pageName, [string]$question) {
    AddVisual $page 'header_band' 0 0 1280 72 (TextVisual @( (Spacer 1) ) (FlatObjects $Navy @(0, 0, 0, 0) 'Decorative header band'))
    AddVisual $page 'header' 0 0 740 72 (TextVisual @( (Para $pageName 11 $Light), (Para $question 20 $White $true) ) (FlatObjects '' @(8, 8, 24, 8) "$pageName. $question"))
    $nav = [ordered]@{
        visualType = 'pageNavigator'
        objects = [ordered]@{
            fill = @(
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $White); transparency = (LD 88) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $White); transparency = (LD 75) }) ([ordered]@{ id = 'hover' })),
                (P ([ordered]@{ show = (LB $true); fillColor = (Fill $Blue); transparency = (LD 0) }) ([ordered]@{ id = 'selected' }))
            )
            text = @(
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $White); fontSize = (LD 10) }) ([ordered]@{ id = 'default' })),
                (P ([ordered]@{ show = (LB $true); fontColor = (Fill $White); fontSize = (LD 10); bold = (LB $true) }) ([ordered]@{ id = 'selected' }))
            )
            outline = @( (Hidden) )
        }
        visualContainerObjects = (FlatObjects '' @(0, 0, 0, 0) 'Page navigation: The headline, Downgrading, An older pool')
        drillFilterOtherVisuals = $true
    }
    AddVisual $page 'page_navigator' 760 10 496 30 $nav
    $period = [ordered]@{
        visualType = 'card'
        query = [ordered]@{ queryState = [ordered]@{ Values = [ordered]@{ projections = @( (Proj (Mea 'Data Period') 'Data period') ) } } }
        objects = [ordered]@{
            labels = @( (P ([ordered]@{ fontSize = (LD 10); fontFamily = (LStr 'Segoe UI'); color = (Fill $Light) })) )
            categoryLabels = @( (Hidden) )
        }
        visualContainerObjects = (FlatObjects '' @(0, 0, 0, 0) 'The period the APRA data on this report covers')
        drillFilterOtherVisuals = $true
    }
    AddVisual $page 'data_period' 760 44 496 22 $period
}

# ---- KPI card with accent strip and hover tooltip
function AddCard([string]$page, [string]$name, [int]$x, [int]$w, [string]$measure, [string]$label, [string]$tip, [string]$strip, [string]$titleMeasure = '', [int]$h = 84) {
    if ($titleMeasure) {
        $title = P ([ordered]@{ show = (LB $true); text = [ordered]@{ expr = (Mea $titleMeasure) }; fontSize = (LD 10); fontColor = (Fill $Muted) })
    } else { $title = Hidden }
    $container = [ordered]@{
        background          = @( (Bg $White) )
        border              = @( (Edge $White 10) )
        dropShadow          = @( (Shadow) )
        padding             = @( (Pad 4 4 24 14) )
        title               = @( $title )
        subTitle            = @( (Hidden) )
        visualHeader        = @( (TooltipHeader) )
        visualHeaderTooltip = @( (P ([ordered]@{ text = (LStr $tip); fontSize = (LD 10) })) )
        general             = @( (AltText "$label. $tip") )
    }
    $visual = [ordered]@{
        visualType = 'card'
        query = [ordered]@{ queryState = [ordered]@{ Values = [ordered]@{ projections = @( (Proj (Mea $measure) $label) ) } } }
        objects = [ordered]@{
            labels = @( (P ([ordered]@{ fontSize = (LD 28); fontFamily = (LStr 'Segoe UI Semibold'); color = (Fill $Ink); labelDisplayUnits = (LD 1) })) )
            categoryLabels = @( (P ([ordered]@{ fontSize = (LD 10); color = (Fill $Muted) })) )
            wordWrap = @( (P ([ordered]@{ show = (LB $true) })) )
        }
        visualContainerObjects = $container
        drillFilterOtherVisuals = $true
    }
    AddVisual $page $name $x 88 $w $h $visual
    AddStrip $page "${name}_strip" ($x + 10) 104 ($h - 32) $strip
}

# ---- charts
$Quarter = Col 'dim_date' 'quarter_end'
function AxisObjects([bool]$legend, [bool]$scalar) {
    $o = [ordered]@{
        valueAxis = @( (P ([ordered]@{ show = (LB $true); gridlineShow = (LB $true); gridlineColor = (Fill $Grid) })) )
    }
    if ($scalar) { $o['categoryAxis'] = @( (P ([ordered]@{ axisType = (LStr 'Scalar') })) ) }
    if ($legend) { $o['legend'] = @( (P ([ordered]@{ show = (LB $true); position = (LStr 'Top') })) ) }
    else { $o['legend'] = @( (Hidden) ) }
    $o
}
function AddLine([string]$page, [string]$name, [int]$x, [int]$y, [int]$w, [int]$h, $series, [string]$title, [string]$sub, $filterConfig = $null, $refLine = $null) {
    $objects = AxisObjects (@($series).Count -gt 1) $true
    $objects['dataPoint'] = @( @($series) | ForEach-Object { P ([ordered]@{ fill = (Fill $_.Color) }) ([ordered]@{ metadata = "_Measures.$($_.Measure)" }) } )
    $objects['lineStyles'] = @( (P ([ordered]@{ strokeWidth = (LD 3) })) )
    if ($null -ne $refLine) { $objects['xAxisReferenceLine'] = @( $refLine ) }
    $visual = [ordered]@{
        visualType = 'lineChart'
        query = [ordered]@{
            queryState = [ordered]@{
                Category = [ordered]@{ projections = @( (Proj $Quarter 'Quarter') ) }
                Y = [ordered]@{ projections = @( @($series) | ForEach-Object { Proj (Mea $_.Measure) $_.Label } ) }
            }
            sortDefinition = (SortBy $Quarter 'Ascending')
        }
        objects = $objects
        visualContainerObjects = (PanelObjects $title $sub)
        drillFilterOtherVisuals = $true
    }
    AddVisual $page $name $x $y $w $h $visual $filterConfig
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
function YearsIn([string]$name, [string]$display, [string[]]$years) {
    $values = New-Object System.Collections.ArrayList
    foreach ($yr in $years) { [void]$values.Add(@( [ordered]@{ Literal = [ordered]@{ Value = "${yr}L" } } )) }
    [ordered]@{ filters = @( [ordered]@{
        name = $name
        displayName = $display
        field = (Col 'dim_date' 'year')
        type = 'Categorical'
        filter = [ordered]@{
            Version = 2
            From = @( [ordered]@{ Name = 'd'; Entity = 'dim_date'; Type = 0 } )
            Where = @( [ordered]@{ Condition = [ordered]@{ In = [ordered]@{
                Expressions = @( [ordered]@{ Column = [ordered]@{ Expression = [ordered]@{ SourceRef = [ordered]@{ Source = 'd' } }; Property = 'year' } } )
                Values = $values
            } } } )
        }
    } ) }
}

# ================================================================ page 1: the headline
NewPage 'headline' 'The headline'
$pg = 'headline'
AddHeader $pg 'The headline' "Membership is at a record. Isn't everything fine?"
AddCard $pg 'card_insured'  24  296 'Insured Persons' 'People with hospital cover' 'People with private hospital cover at the end of the latest quarter, Australia-wide.' $Blue
AddCard $pg 'card_change'   336 296 'Insured Persons, Change on a Year Earlier' 'Change on a year earlier' 'People with hospital cover, against the same quarter a year earlier.' $Blue
AddCard $pg 'card_coverage' 648 296 'Coverage Rate' 'Share of Australians covered' "People with hospital cover as a share of Australia's population, at the end of the latest quarter." $Orange
AddCard $pg 'card_policies' 960 296 'Hospital Policies' 'Hospital policies' 'Hospital policies at the end of the latest quarter. One policy can cover several people.' $Grey
AddLine $pg 'insured_by_quarter' 24 188 608 216 @( @{ Measure = 'Insured Persons'; Label = 'People with hospital cover'; Color = $Blue } ) `
    'A record 12.8 million people now have hospital cover, up 40% since 2007' `
    'People with hospital cover at the end of each quarter, Australia-wide.'
AddLine $pg 'coverage_by_quarter' 648 188 608 216 @( @{ Measure = 'Coverage Rate'; Label = 'Share covered'; Color = $Orange } ) `
    '…but the share of Australians covered, 45.8%, is still below its 2015 peak of 47.4%' `
    'People with hospital cover as a share of the population, at the end of each quarter.'
$noteText1 = "Every card and chart uses APRA's private health insurance statistics, quarterly and annual. Population figures are the ABS's, as APRA publishes them."
$noteText2 = 'Coverage is people with hospital cover divided by the population. People, policies and population are each counted at the end of a quarter.'
$noteText3 = 'The chart titles describe the June 2026 release.'
AddNote $pg 'source_note' 24 420 496 276 @(
        (Para 'Where the numbers come from' 13 $Ink $true), (Spacer 4),
        (Para $noteText1 10 $Muted), (Spacer 4),
        (Para $noteText2 10 $Muted), (Spacer 4),
        (Para $noteText3 10 $Ink $true)
    ) "Where the numbers come from. $noteText1 $noteText2 $noteText3" $Grey
# Matches comes from a measure, so the table says Yes rather than True; the SQL view is unchanged.
# The table is tall enough for all five rows with about a row and a half to spare. The widths add
# up to 645 of its 692 px inner width, leaving room for cell padding, so it never scrolls either
# way; 440 keeps every measure name on one line.
$recon = @(
    @{ Field = (Col 'reconciliation_panel' 'measure'); Label = 'Measure'; Width = 440 },
    @{ Field = (Col 'reconciliation_panel' 'published_display'); Label = 'Published'; Width = 70 },
    @{ Field = (Col 'reconciliation_panel' 'ours_display'); Label = 'Ours'; Width = 75 },
    @{ Field = (Mea 'Reconciliation Match'); Label = 'Matches'; Width = 60 }
)
$tableTitle = 'Checked against published figures: 5 of 5 match'
$tableSub = "Five figures published by the ACCC, APRA and CHOICE, each rebuilt from APRA's raw spreadsheets."
$table = [ordered]@{
    visualType = 'tableEx'
    query = [ordered]@{ queryState = [ordered]@{ Values = [ordered]@{ projections = @( $recon | ForEach-Object { Proj $_.Field $_.Label } ) } } }
    objects = [ordered]@{
        total = @( (P ([ordered]@{ totals = (LB $false) })) )
        columnWidth = @( $recon | ForEach-Object { P ([ordered]@{ value = (LD $_.Width) }) ([ordered]@{ metadata = (Proj $_.Field '').queryRef }) } )
    }
    visualContainerObjects = (PanelObjects $tableTitle $tableSub)
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'reconciliation' 536 420 720 276 $table

# ================================================================ page 2: downgrading
NewPage 'downgrading' 'Downgrading'
$pg = 'downgrading'
AddHeader $pg 'Downgrading' 'Are people downgrading instead of leaving?'
AddCard $pg 'card_policies'   24  400 'Hospital Policies' 'Hospital policies' 'Hospital policies at the end of the latest quarter. One policy can cover several people.' $Blue
AddCard $pg 'card_full_cover' 440 400 'Full Cover Share' 'With full cover' 'Share of hospital policies with full cover: no reduced cover and no lifetime exclusions. Latest quarter.' $Orange
AddCard $pg 'card_excess'     856 400 'Excess Over 500 Share' 'With an excess over 500 dollars' 'Share of hospital policies with an excess over 500 dollars for a single person. Latest quarter.' $Orange

$areaTitle = 'Policies grew 43.5% since 2007, but only 26.8% now give full cover, down from 63.6%'
$areaSub = 'Share of hospital policies by cover, at the end of each quarter. Not full cover means reduced cover, lifetime exclusions, or both.'
$coverGroup = Col 'dim_cover' 'cover_group'
$areaObjects = AxisObjects $true $true
$areaObjects['dataPoint'] = @(
    (P ([ordered]@{ fill = (Fill $Grey) }) (ScopeEq $coverGroup "'Full cover'")),
    (P ([ordered]@{ fill = (Fill $Orange) }) (ScopeEq $coverGroup "'Not full cover'"))
)
$area = [ordered]@{
    visualType = 'hundredPercentStackedAreaChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj $Quarter 'Quarter') ) }
            Series   = [ordered]@{ projections = @( (Proj $coverGroup 'Cover') ) }
            Y        = [ordered]@{ projections = @( (Proj (Mea 'Hospital Policies') 'Hospital policies') ) }
        }
        sortDefinition = (SortBy $Quarter 'Ascending')
    }
    objects = $areaObjects
    visualContainerObjects = (PanelObjects $areaTitle $areaSub)
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'cover_by_quarter' 24 188 808 232 $area

$renew = @(
    (Para 'Before you renew, check' 15 $Ink $true), (Spacer 6),
    (Para ([char]0x2022 + '  Whether the policy excludes treatments you may need') 11 $Muted), (Spacer 4),
    (Para ([char]0x2022 + '  What your excess is for each hospital admission') 11 $Muted), (Spacer 4),
    (Para ([char]0x2022 + '  What changed in your cover at renewal') 11 $Muted)
)
AddNote $pg 'renew_note' 848 188 408 232 $renew 'Before you renew, check: whether the policy excludes treatments you may need; what your excess is for each hospital admission; what changed in your cover at renewal.' $Blue

$ruleLine = P ([ordered]@{
    show = (LB $true)
    displayName = (LStr '1 Apr 2019: maximum excess rises to 750 dollars single')
    value = (L "datetime'2019-04-01T00:00:00'")
    lineColor = (Fill $Muted)
    transparency = (LD 0)
    style = (LStr 'dashed')
    position = (LStr 'front')
    dataLabelShow = (LB $false)
}) ([ordered]@{ id = '1' })
AddLine $pg 'excess_by_quarter' 24 436 608 260 @( @{ Measure = 'Excess Over 500 Share'; Label = 'Excess over 500 dollars'; Color = $Orange } ) `
    'Since the April 2019 rule change, policies with an excess over 500 dollars went from 0.5% to 29.4%' `
    "Share of hospital policies with an excess over 500 dollars (single), from September 2010. Earlier quarters are left out: the share drops 4.1 points that quarter, and APRA's notes do not explain why." `
    (FromDate 'fromSep2010' 'From September 2010' '2010-09-30T00:00:00') $ruleLine

# The line's own label crossed the dashed line and the orange line, so the guide's fallback: a
# label in the chart's empty left half. The dashed line falls near x 362; the label ends at 320.
# Before 2019 the orange line stays flat near the bottom, so the label sits above it, with room
# for both lines of text.
$ruleLabel = @(
    (Para '1 Apr 2019: maximum excess' 9 $Muted $false 'right'),
    (Para 'rises to 750 dollars single' 9 $Muted $false 'right')
)
AddVisual $pg 'excess_rule_label' 90 572 230 60 (TextVisual $ruleLabel (FlatObjects '' @(0, 0, 0, 0) '1 April 2019: maximum excess rises to 750 dollars single'))

# Columns, not bars: horizontal bars kept a minimum height that hid the eighth state behind a
# scroll bar. Eight columns across the chart are about 70 px each, far from any minimum. The axis
# uses the state codes. No tooltip field: a column in Tooltips becomes part of each column's
# identity, and the WA colour rule, which names only the state code, then matched nothing.
$stateCode = Col 'dim_state' 'state'
$bar = [ordered]@{
    visualType = 'clusteredColumnChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj $stateCode 'State') ) }
            Y        = [ordered]@{ projections = @( (Proj (Mea 'Full Cover Share') 'With full cover') ) }
        }
        sortDefinition = (SortBy (Mea 'Full Cover Share') 'Ascending')
    }
    objects = [ordered]@{
        dataPoint = @(
            (P ([ordered]@{ fill = (Fill $Grey) })),
            (P ([ordered]@{ fill = (Fill $Orange) }) (ScopeEq $stateCode "'WA'"))
        )
        labels    = @( (P ([ordered]@{ show = (LB $true); fontSize = (LD 10); color = (Fill $Ink) })) )
        valueAxis = @( (Hidden) )
        legend    = @( (Hidden) )
    }
    visualContainerObjects = (PanelObjects 'Full cover is rarest in WA (23.1%) and most common in Tasmania (38.7%)' 'Share of hospital policies with full cover, latest quarter.')
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'full_cover_by_state' 648 436 608 260 $bar

# ================================================================ page 3: an older pool
NewPage 'older_pool' 'An older pool'
$pg = 'older_pool'
AddHeader $pg 'An older pool' 'Is the pool getting older?'
# All three cards describe the same June, so each shows it; the taller cards keep every label visible.
AddCard $pg 'card_insured_65'   24  400 'Share Aged 65+, Insured' 'Insured people aged 65+' 'Share of people with hospital cover who are aged 65 or over, in the latest June with population figures by age.' $Orange 'Population Year' 108
AddCard $pg 'card_australia_65' 440 400 'Share Aged 65+, Australia' 'All Australians aged 65+' 'Share of all Australians aged 65 or over, in the same June.' $Grey 'Population Year' 108
AddCard $pg 'card_gap'          856 400 'Age Gap (points)' 'Gap, percentage points' "How many percentage points the insured pool's 65+ share runs ahead of Australia's, in the same June." $Orange 'Population Year' 108
AddLine $pg 'share_65_by_june' 24 212 1232 228 @(
        @{ Measure = 'Share Aged 65+, Insured'; Label = 'Insured people'; Color = $Orange },
        @{ Measure = 'Share Aged 65+, Australia'; Label = 'All Australians'; Color = $Grey }
    ) `
    'Insured people are ageing faster than Australia: aged 65+ rose from 13.3% to 20.7% of the insured, against 13.1% to 17.4% of everyone' `
    'Share of people aged 65 or over, each June: people with hospital cover against all Australians.'

$year = Col 'dim_date' 'year'
$ageBand = Col 'dim_age_band' 'age_band'
$columnsObjects = AxisObjects $true $false
$columnsObjects['dataPoint'] = @(
    (P ([ordered]@{ fill = (Fill $Grey) }) (ScopeEq $year '2007L')),
    (P ([ordered]@{ fill = (Fill $Orange) }) (ScopeEq $year '2025L'))
)
$columns = [ordered]@{
    visualType = 'clusteredColumnChart'
    query = [ordered]@{
        queryState = [ordered]@{
            Category = [ordered]@{ projections = @( (Proj $ageBand 'Age') ) }
            Series   = [ordered]@{ projections = @( (Proj $year 'Year') ) }
            Y        = [ordered]@{ projections = @( (Proj (Mea 'Coverage Rate by Age') 'With hospital cover') ) }
        }
        sortDefinition = (SortBy $ageBand 'Ascending')
    }
    objects = $columnsObjects
    visualContainerObjects = (PanelObjects 'Coverage rose most among 80- to 89-year-olds, up 18 to 19 points since 2007, and fell among 25- to 34- and 50- to 64-year-olds' 'Share of each age band with hospital cover, June 2007 against June 2025. National figures.')
    drillFilterOtherVisuals = $true
}
AddVisual $pg 'coverage_by_age' 24 456 920 240 $columns (YearsIn 'years2007and2025' 'June 2007 and June 2025' @('2007', '2025'))

$aboutText = "These figures are for Australia as a whole: APRA's population by age has no state breakdown. In June 2018 its population table lacks women aged 95+, so Australia's 65+ share is slightly understated that year."
AddNote $pg 'about_note' 960 456 296 240 @(
        (Para 'About this page' 13 $Ink $true), (Spacer 4),
        (Para $aboutText 10 $Muted)
    ) "About this page. $aboutText" $Grey

# ================================================================ serialise and check, before writing
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
    $page = [ordered]@{
        '$schema' = $pageSchema; name = $name; displayName = $pages[$name].Display; displayOption = 'FitToPage'
        height = 720; width = 1280
        objects = [ordered]@{
            background = @( (P ([ordered]@{ color = (Fill $PageBg); transparency = (LD 0) })) )
            outspace   = @( (P ([ordered]@{ color = (Fill $PageBg); transparency = (LD 0) })) )
        }
    }
    $files[(Join-Path $pagesDir "$name\page.json")] = J $page
    foreach ($v in $pages[$name].Visuals) {
        $files[(Join-Path $pagesDir "$name\visuals\$($v.name)\visual.json")] = J $v
    }
}
$files[(Join-Path $pagesDir 'pages.json')] = J ([ordered]@{ '$schema' = $pagesSchema; pageOrder = @($pages.Keys); activePageName = 'headline' })

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

# ================================================================ write
$oldPage = Join-Path $pagesDir 'e85a289f4f695fef338b'
if (Test-Path -LiteralPath $oldPage) {
    $contents = @(Get-ChildItem -LiteralPath $oldPage -Recurse -File)
    if ($contents.Count -ne 1 -or $contents[0].Name -ne 'page.json') { throw "The old page holds more than page.json; stopping" }
}
foreach ($name in $pages.Keys) { if (Test-Path -LiteralPath (Join-Path $pagesDir $name)) { throw "Page folder $name already exists; stopping" } }

if (Test-Path -LiteralPath $oldPage) { Remove-Item -LiteralPath $oldPage -Recurse }
foreach ($path in $files.Keys) {
    New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($files[$path] -replace "`n", "`r`n"), $utf8)
}

"Wrote $($files.Count) files; $($found.Count) distinct field references, all in the model."
foreach ($name in $pages.Keys) {
    ''
    "== $name ($($pages[$name].Display)): $($pages[$name].Visuals.Count) visuals"
    foreach ($v in $pages[$name].Visuals) {
        $vis = $v.visual
        $fields = @()
        if ($vis.Contains('query')) {
            foreach ($role in $vis.query.queryState.Keys) { foreach ($pr in $vis.query.queryState[$role].projections) { $fields += "$role=$($pr.displayName)" } }
        }
        $t = ''
        if ($vis.visualContainerObjects.Contains('title')) {
            $tp = $vis.visualContainerObjects.title[0].properties
            if ($tp.Contains('text')) { $t = if ($tp.text.expr.Contains('Literal')) { $tp.text.expr.Literal.Value } else { '[Population Year]' } }
        }
        $flt = if ($v.Contains('filterConfig')) { ' | filter: ' + $v.filterConfig.filters[0].displayName } else { '' }
        '{0,-24} {1,-31} {2,4},{3,-4} {4,4}x{5,-4} {6}{7}{8}' -f $v.name, $vis.visualType, $v.position.x, $v.position.y, $v.position.width, $v.position.height, ($fields -join '; '), $(if ($t) { " | title: $t" } else { '' }), $flt
    }
}
