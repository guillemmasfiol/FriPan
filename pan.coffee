
# block width and heightl, one block per gene per species
bw = 1
bh = 10
bcolouron = "green"
bcolouroff = "lightgray"

class Pan
    brushed: (brush) ->
        #x.domain(if brush.empty() then x2.domain() else brush.extent())
        # focus.select("path").attr("d", area)
        #focus.select(".x.axis").call(xAxis)
        ex = brush.extent()
        diff = ex[1] - ex[0]
        if diff==0
            # Reset to full zoom
            @set_scale(0, @width/(bw*@matrix.genes().length))
            @redraw_pca(null)
        else if diff > 1  # only sane scaling please
            sc = (@width / diff)
            #console.log "brushed", brush.extent(), diff, "scale=", sc, "width", width
            @set_scale(ex[0], sc)
            @redraw_pca(ex)

    redraw_pca: (range) ->
        range = [0, @matrix.genes().length-1] if !range
        range = [Math.floor(range[0]), Math.ceil(range[1])]
        console.log "drawing",range
        mds = MDS.cmdscale(MDS.distance(@matrix, range))
        @scatter.draw([mds.xs,mds.ys], @matrix.strains(), [0,1])

    # should the x-translate NOT be scaled?
    set_scale: (pos,sc) ->
      @svg.selectAll(".scale").attr("transform","translate(#{-pos*sc},0) scale(#{sc},1)")


    detail: () ->
        [x,y] = d3.mouse(@focus.node())
        # convert from screen coordinates to matrix coordinates
        row = Math.round(y/bh)
        col = Math.round(x/bw)  # dave didn't have /bw here -- because it was set to 1 ?
        strain = @matrix.strains()[row]
        gene = @matrix.genes()[col]
        p = @matrix.presence(row,col)
    #    $('#info').text("Strain:#{strain}  Gene:#{gene}  present:#{p}")
        @tooltip.style("display", "block") # un-hide it (display: none <=> block)
               .style("left", (d3.event.pageX) + "px")
               .style("top", (d3.event.pageY) + "px")
               .select("#tooltip-text")
                   .html("<b>Strain:</b> #{strain}<br/><b>Gene:</b> #{gene.name}</br><b>Product:</b> #{gene.desc}<br/><b>Present:</b> #{p}")

    create_elems: () ->
        tot_width = $(@elem).width()
        tot_height = bh * @matrix.strains().length + 200
        margin = {top: 150, right: 10, bottom: 10, left: 140}
        margin2 = {top: 50, right: margin.right, bottom: tot_height - 100, left: margin.left}
        @width = tot_width - margin.left - margin.right
        @height = tot_height - margin.top - margin.bottom
        @height2 = tot_height - margin2.top - margin2.bottom

        @x2 = d3.scale.linear().range([0, @width])

        #x2.domain([0,2846])
        @xAxis2 = d3.svg.axis().scale(@x2).orient("bottom")

        brush = d3.svg.brush()
        brush.x(@x2)
             .on("brush", () => @brushed(brush))

        # should tot_width here be width?
        @svg = d3.select(@elem).append("svg")
            .attr("width", tot_width)
            .attr("height", tot_height)

        # Add a clip rectangle to keep the area inside
        @svg.append("svg:defs")
           .append("svg:clipPath")
            .attr("id", "circle1")  # what is circle1?
           .append('rect')
            .attr('width', @width)
            .attr('height',@height)
            .attr('x', 0)
            .attr('y', 0)

        # set up SVG for gene content pane

        @focus = @svg.append("g")
                     .attr("clip-path", "url(#circle1)")
                     .attr("transform", "translate(#{margin.left},#{margin.top})")
                   .append("g")
                     .attr("transform","translate(0,0)scale(1,1)")
                     .attr("class", "scale")
                     .on("mousemove", () => @detail())
                     .on("mouseout", () => @tooltip.style("display", "none"))


        # set up SVG for brush selection
        @context = @svg.append("g")
            .attr( "transform", "translate(#{margin2.left},#{margin2.top})" );

        # Create - @mini a <g> to hold the small plot
        # FIXME.  Factor out this scaling.  width should be like "set scale full".  Heightt should depend on number of strains
        @mini = @context.append("g")
                        .attr("class", "minimap")
                        .attr("transform","translate(0,0)
                                           scale(#{@width/(bw*@matrix.genes().length)},
                                           #{@height2/(bh*@matrix.strains().length)})")

        @context.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0,#{@height2})")
            .call(@xAxis2)

        @context.append("g")
            .attr("class", "x brush")
            .call(brush)
          .selectAll("rect")
            .attr("y", -6)
            .attr("height", @height2 + 7)

        # set up label area
        @labels = @svg.append("g")
             .attr("transform", "translate(0,#{margin.top})")
             .attr("width", margin.left)
             .attr("height", @height)

        # set tooltip object
        @tooltip = d3.select("#tooltip")


    draw_boxes: (elem) ->
        box = (x,y,w) ->
                      elem.append('rect')
                          .attr('width',  w*bw)
      		              .attr('height', bh-1)
      		              .attr('x',x*bw)
      		              .attr('y',y*bh)
      		              .attr('fill', bcolouroff)
      		              #.attr('opacity', 1-p)

        for i in [0 ... @matrix.strains().length]
            do (i) =>
         	    # draw big rectangle first, then blank out missing genes
                elem.append('rect')
                    .attr('width', bw*@matrix.genes().length)
                    .attr('height',bh-1)
                    .attr('x', 0)
                    .attr('y', i*bh)
                    .attr('fill', bcolouron)
                    .attr('class', "row strain-#{i}")

                # paint where the gene is ABSENT
                last_j = null
                for j in [0 ... @matrix.genes().length]
                    p = @matrix.presence(i,j)
                    if p==1
                        if last_j
                            box(last_j, i, j-last_j)
                            last_j = null
                        continue
                    if !last_j
                        last_j=j

                if last_j
                    box(last_j, i, j-last_j)

    draw_chart: () ->
        @x2.domain([0, @matrix.genes().length])

        #xAxis2.tickFormat((d) -> genes[d])
        @context.select(".x.axis").call(@xAxis2)

        @draw_boxes(@mini)

        @draw_boxes(@focus)
        for i in [0 ... @matrix.strains().length]
            do (i) =>
                # draw strain labels
                @labels.append('text')
                    .text(@matrix.strains()[i])
                    .attr('class',"strain-#{i}")
                    .attr('x', 0)
                    .attr('y', (i+1)*bh-1)   # i+1 as TEXT is from baseline not top
                    .on("mouseover", () -> d3.selectAll(".strain-#{i}").classed({'highlight':true}))
                    .on("mouseout", () -> d3.selectAll(".strain-#{i}").classed({'highlight':false}))

            # TODO: set font size to be same as row height?
            # TODO: right-align the text?

        # commence completely zoomed out
        @set_scale(0, @width/(bw*@matrix.genes().length))

    constructor: (@elem, @matrix) ->
        @create_elems()
        @draw_chart()
        @scatter = new ScatterPlot('#pca')
        @redraw_pca(null)

    # Resize.  Just redraw everything!
    # TODO : Would be nice to maintain current brush on resize
    resize: () ->
        @svg.remove()
        @create_elems()
        @draw_chart()

class Gene
    constructor: (@name, @desc) ->
        # Pass

class GeneMatrix
    constructor: (@_strains, @_genes, @_values) ->
        # Pass
    strains: () ->
        @_strains
    genes: () ->
        @_genes
    presence: (strain, gene) ->
        @_values[strain][gene]


# Load a Torsty home-brew .CSV ortholog file
# This needs to be deprecated, not sure how I generated it!

parse_csv = (csv) ->
    strains = []
    values = []
    genes = []
    i=0
    for row in csv
        i += 1
        if i==1
            genes = d3.keys(row).map((g) -> new Gene(g, row[g]))
            continue
        val_row = []
        values.push(val_row)
        j=0
        for k,v of row
            if k==''
                strains.push(v)
                continue
            j+=1
            p = parseInt(v)
            val_row.push(p)
    new GeneMatrix(strains,genes,values)


# Load a ProteinOrtho5 output file
# Please use -singles option to ensure singleton clusters are included!
# http://www.bioinf.uni-leipzig.de/Software/proteinortho/

parse_proteinortho = (tsv) ->
    strains = []
    values = []
    genes = []
    i=0
    for row in tsv
        i += 1
        if i==1
            strains = d3.keys(row)[3..] # skip first 3 junk columns
            console.log "STRAINS: #{strains}"
        genes.push( new Gene("cluster#{i}", "") )
        values.push( strains.map( (s) -> if row[s]=='*' then 0 else 1) )

    new GeneMatrix( strains, genes, d3.transpose(values) )


# Load an OrthoMCL 1.4 output file  (2.0 not supported)
# (does not output singleton clusters)
# http://orthomcl.org/common/downloads/software/v2.0/

parse_orthomcl = (tsv) ->
	# FIXME


# main()

init = () ->

    $('.by').mouseover(() -> $('.gravatar').show())
    $('.by').mouseout(() -> $('.gravatar').hide())

#    d3.csv("pan.csv", (data) ->
    d3.tsv("pan.proteinortho", (data) ->
        matrix = parse_proteinortho(data)

        console.log "Features : ",matrix.genes()
        console.log "Strains : ",matrix.strains()

        d3.select("#topinfo")
            .html("Loaded #{matrix.strains().length} strains and #{matrix.genes().length} ortholog clusters")


        pan = new Pan('#chart', matrix)

        $( window ).resize(() -> pan.resize())
    )

$(document).ready(() -> init() )
