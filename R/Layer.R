
#' Class that encapsulates a layer used for dispalying slices of a 3D volume.
#'
#' @docType class
#' @importFrom R6 R6Class
#' @export
#' @field vol an object of class \code{\linkS4class{NeuroVol}} supplying the image data
#' @field color_map the color map
#' @field threshold the low and high thresholds to determine transparency.
#' @field irange the intensity range of the low and high end of color scale.
#' @field view the orientation code (e.g. "LPI") describing the display axes.
#' @field zero_col the color assigned to values of 0.
#' @field alpha the degree of opacity for the layer (0 = transparent, 1 = opaque)
#' @field view_space the \code{linkS4class{NeuroSpace}} associaed with the view.
#' @field view_axes
#' @field value_range the full numeric range of the underlying volume
#' @field desc a short \code{character} description of the layer
#' @return Object of \code{\link{R6Class}} with methods for accessing and changing layer properties.
#' @format \code{\link{R6Class}} object.
Layer <- R6Class("Layer",
             portable = TRUE,
             public = list(
               vol = NULL,
               color_map=NULL,
               threshold=NULL,
               irange=NULL,
               view=NULL,
               zero_col=NULL,
               alpha=NULL,
               view_space=NULL,
               view_axes=NULL,
               value_range=NULL,
               desc=NULL,

               initialize = function(vol, color_map=gray((0:255)/255, alpha=1), threshold=c(0,0),
                                     irange=range(vol),
                                     view="LPI", zero_col="#000000FF", alpha=1, desc="") {
                 self$vol=vol
                 self$color_map=color_map
                 self$threshold=threshold
                 self$view=view
                 self$zero_col=zero_col
                 self$alpha=alpha
                 self$irange=irange
                 self$value_range=range(vol)

                 view <- if (length(view) == 1 && nchar(view) == 3) {
                   sapply(1:3, function(i) substr(view, i,i))
                 } else {
                   view
                 }

                 stopifnot(length(view) == 3)

                 self$view_axes <- neuroim2:::findAnatomy3D(view[1], view[2], view[3])
                 self$view_space <- reorient(space(vol), view)
               },

               slice=function(zpos) {
                 slice(self$vol, zpos, self$view_space, self$view_axes)
               },
               set_irange = function(new_range) {
                 self$irange = new_range
               },
               set_color_map = function(cmap) {
                 self$color_map = cmap
               },

               set_alpha = function(alpha) {
                 assertthat::assert_that(alpha>= 0 && alpha <=1)
                 self$alpha=alpha
               },

               set_threshold = function(threshold) {
                 assertthat::assert_that(length(threshold) == 2)
                 assertthat::assert_that(diff(threshold) >= 0)
                 self$threshold=threshold
               },

               get_color_map = function() { self$color_map },

               get_zpos = function(zlevel) {
                 zprop <- zlevel/self$zdim()

                 zr <- self$zrange()
                 zoffset <- zprop * diff(zr)

                 zoffset + zr[1]
               },

               get_zlevel = function(zpos) {
                 bds <- bounds(self$view_space)
                 zdiff <- zpos - bds[3,1]
                 round(zdiff/self$zspacing())
               },

               zdim=function() { dim_of(space(self$vol), self$view_axes@k) },

               zrange=function() {
                 bds <- bounds(self$view_space)
                 zrange <- sort(bds[3,])
               },

               zspacing=function() {
                 dnum <- which_dim(space(self$vol), self$view_axes@k)
                 spacing(self$vol)[dnum]
               },

               ## render nearest discrete slice, given a z-coordinate
               render_slice=function(zpos) {

                 bds <- bounds(self$view_space)
                 zran <- self$zrange()

                 zlevel <- (zpos - zran[1])/self$zspacing()
                 zdim <- self$zdim()

                 if (zlevel >= 1 && zlevel <= zdim) {
                   zlevel <- round(zlevel)
                 } else if (zlevel >= 0 && zlevel <= 1) {
                   zlevel <- 1
                 } else if (zlevel >= zdim) {
                   zlevel <- zdim
                 } else if (zlevel < 1) {
                   zlevel <- 1
                 } else {
                   stop(paste("zpos outside z bounds: ", zpos, " bounds: ", zran))
                 }



                 ## extract slice
                 slice <- slice(self$vol, zlevel, self$view_space, self$view_axes)

                 ## reorder y-axis (needed for correct orientation using grid.raster)
                 imslice <- t(slice[1:nrow(slice), ncol(slice):1,drop=FALSE])
                 ## map intensities to colors
                 imcols <- mapToColors(imslice, self$color_map, self$zero_col, alpha=self$alpha,
                                       irange=self$irange, threshold=self$threshold)

                 ras <- as.raster(imcols)


                 RenderedSlice$new(slice=slice, width=dim(slice)[1], height=dim(slice)[2],
                                   xbounds=bds[1,], ybounds=bds[2,], raster=ras, zpos=zpos, zlevel=zlevel)
               }
             )
)

#' Class that describes a stack of image Layers
#'
#' @field layers a \code{list} of \code{Layer} objects
#' @field view_space
#' @field view_axes
#' @field layer_names
#'
#' @docType class
#' @importFrom R6 R6Class
#' @export
Overlay <- R6Class("Overlay",
                   portable=TRUE,
                   public = list(
                     layers=NULL,
                     view_space=NULL,
                     view_axes=NULL,
                     layer_names=NULL,

                     initialize = function(...) {
                      layers=list(...)
                      lapply(layers, function(x) stopifnot(inherits(x, "Layer")))

                      splist <- lapply(layers, function(layer) space(layer$vol))
                      axes <- sapply(splist, function(x) x@axes)
                      bds <- lapply(splist, function(x) signif(dim(x) * spacing(x),3))
                      views <- lapply(layers, function(x) x$view_axes)

                      if (length(layers) > 1) {
                        #orgs <- do.call(rbind, lapply(splist, function(x) signif(origin(x),3)))
                        #dorgs <- apply(orgs, 2, function(x) max(abs(diff(x))))
                        #browser()
                        #assertthat::assert_that(all(dorgs < 2))
                      }


                      assertthat::assert_that(length(unique(views)) == 1)
                      assertthat::assert_that(length(unique(axes)) == 1)
                      #assertthat::assert_that(length(unique(bds)) == 1)


                      self$view_space=layers[[1]]$view_space
                      self$view_axes=layers[[1]]$view_axes

                      lnames <- names(layers)

                      if (is.null(lnames)) {
                        lnames <- paste0("Layer_", 1:length(layers))
                      }
                      self$layer_names=lnames
                      self$layers=layers

                   },

                   zdim = function() { self$layers[[1]]$zdim() },

                   get_zpos = function(zlevel) { self$layers[[1]]$get_zpos(zlevel) },

                   names = function() { self$layer_names },

                   length = function() { length(self$layers) },

                   get_layer = function(i) self$layers[[i]],

                   set_irange = function(layer_index, new_range) {
                     self$layers[[layer_index]]$set_irange(new_range)
                   },

                   set_color_map = function(layer_index, cmap) {
                     self$layers[[layer_index]]$set_color_map(cmap)
                   },

                   set_threshold = function(layer_index, threshold) {
                     assertthat::assert_that(length(threshold) == 2)
                     assertthat::assert_that(diff(threshold) >= 0)
                     self$layers[[layer_index]]$set_threshold(threshold)
                   },

                   set_alpha = function(layer_index, alpha) {
                     self$layers[[layer_index]]$set_alpha(alpha)
                   },


                   render_slice=function(zpos, selected=NULL, width=NULL, height=NULL) {

                     if (is.null(selected)) {
                       selected <- 1:length(self$layers)
                     }


                     bds <- bounds(self$view_space)
                     bds <- t(apply(bds,1,sort))[1:2,]

                     wi <- diff(bds[1,])
                     hi <- diff(bds[2,])
                     aspect_ratio <- wi/hi

                     rs <- width/height
                     if (rs > aspect_ratio) {
                      width <- wi * height/hi
                     } else {
                      height <- hi * width/wi
                     }

                     sx <- width/diff(bds[1,])
                     sy <- height/diff(bds[2,])

                     sliceList <- lapply(self$layers, function(layer) {
                       layer$render_slice(zpos=zpos)
                     })

                     slices <- lapply(sliceList, function(x) x$slice)
                     grobList <- lapply(sliceList, function(x) x$get_grob(sx,sy))

                     gl <- do.call(gList, grobList)

                     RenderedSliceStack$new(slices=sliceList, view_space=self$view_space,
                                            view_axes=self$view_axes,
                                            width=width, height=height,
                                            xbounds=sliceList[[1]]$xbounds,
                                            ybounds=sliceList[[1]]$ybounds,
                                            grobList=gl,
                                            zpos=sliceList[[1]]$zpos)


                   }
                )
)



#' @field slice
#' @field width
#' @field height
#' @field xbounds
#' @field ybounds
#' @field raster
#' @field zpos
#' @field zlevel
#' @export
#' @importFrom grid rasterGrob unit
RenderedSlice <- R6Class("RenderedSlice",
                         portable=TRUE,
                         public = list(
                           slice=NULL,
                           width=NULL,
                           height=NULL,
                           xbounds=NULL,
                           ybounds=NULL,
                           raster=NULL,
                           zpos=NULL,
                           zlevel=NULL,
                           initialize = function(slice, width, height, xbounds,  ybounds, raster, zpos, zlevel) {
                             self$slice=slice
                             self$width=width
                             self$height=height
                             self$xbounds=xbounds
                             self$ybounds=ybounds
                             self$raster=raster
                             self$zpos=zpos
                             self$zlevel=zlevel
                           },

                           get_grob = function(sx=1, sy=1) {
                             #browser()
                             grob <- grid::rasterGrob(self$raster,
                                                width=unit(spacing(self$slice)[1] * dim(self$slice)[1] * sx, "points"),
                                                height=unit(spacing(self$slice)[2] * dim(self$slice)[2] * sy, "points"),
                                                interpolate=TRUE)
                           },

                           draw = function(width, height) {
                             #grid.newpage()
                             #grid.rect(gp=gpar(fill="black"))
                             grob <- rasterGrob(self$raster,
                                                width=width,
                                                height=height,
                                                interpolate=TRUE)
                             grid.draw(grob)
                           }

                         )

)


#' Class representing a stack of rendered slices.
#'
#' @field slices
#' @field width
#' @field height
#' @field xbounds
#' @field ybounds
#' @field grobList
#' @field zpos
#' @field view_space
#' @field view_axes
#' @docType class
#' @export
RenderedSliceStack <-
  R6Class("RenderedSliceStack",
    portable = TRUE,
    public = list(
      slices = NULL,
      width = NULL,
      height = NULL,
      xbounds = NULL,
      ybounds = NULL,
      grobList = NULL,
      zpos = NULL,
      view_space=NULL,
      view_axes=NULL,
      initialize = function(slices,
                            view_space,
                            view_axes,
                            width,
                            height,
                            xbounds,
                            ybounds,
                            grobList,
                            zpos) {
        self$slices = slices
        self$view_space=view_space
        self$view_axes=view_axes
        self$width = width
        self$height = height
        self$xbounds = xbounds
        self$ybounds = ybounds
        self$grobList = grobList
        self$zpos = zpos
      },

      draw = function(marker_pos = NULL,
                      marker_col = "white") {

        grid.newpage()

        ## fill black background
        grid.rect(gp = gpar(fill = "black"), name =
                    "background_fill")

        ## draw slice rasters
        grid.draw(self$grobList)

        ## size of background rect
        frame_width <-
          as.numeric(convertX(grobWidth(grid.get(
            "background_fill"
          )), "points"))
        frame_height <-
          as.numeric(convertY(grobHeight(grid.get(
            "background_fill"
          )), "points"))
        image_width <-
          as.numeric(convertX(grobWidth(grid.get(
            self$grobList[[1]]$name
          )), "points"))
        image_height <-
          as.numeric(convertY(grobHeight(grid.get(
            self$grobList[[1]]$name
          )), "points"))

        xoffset <- (frame_width - image_width) / 2

        yoffset <- (frame_height - image_height) / 2

        convert_xy <- function(x, y) {
          ## horrific fudge to deal with shiny negative mouse coordinates...
          x0 <- ( (x - -.04)/1.0764 * frame_width) - xoffset
          y0 <- ( (y - -.04)/1.0764 * frame_height) - yoffset
          c(x0 / image_width, y0 / image_height)
        }

        if (!is.null(marker_pos)) {

          marker_pos <- t(perm_mat(self$view_axes)) %*% marker_pos
          bds <- bounds(self$view_space)
          bds <- t(apply(bounds(self$view_space), 1, sort))
          xc <- xoffset + (marker_pos[1] - bds[1,1])/diff(bds[1,]) * image_width
          yc <- yoffset + (marker_pos[2] - bds[2,1])/diff(bds[2,]) * image_height

          if (self$view_axes@i@axis == "Left-to-Right" &&
              self$view_axes@j@axis == "Posterior-to-Anterior" && marker_pos[1] < -90) {
            #print(paste("marker_pos", marker_pos[1], marker_pos[2], marker_pos[3]))
            #print(paste("xc: ", xc))
            #print(paste("yc: ", yc))

          }


          ## draw crosshair
          grid.lines(x=unit(c(xoffset, xoffset+image_width),"points"),
                     y=unit(c(yc,yc),"points"),
                     gp=gpar(col="green", lwd=2, lty=2))

          grid.lines(x=unit(c(xc, xc),"points"),
                     y=unit(c(yoffset,yoffset+image_height),"points"),
                     gp=gpar(col="green", lwd=2, lty=2))
        }

        list(
          frame_width = frame_width,
          frame_height = frame_height,
          image_width = image_width,
          image_height = image_height,
          xoffset = xoffset,
          yoffset = yoffset,
          convert_xy = convert_xy
        )

      }

    )
  )


ColorMaps <- R6Class("ColorMaps",
                     portable=TRUE,
                     public=list(
                       map_names=c("grayscale", "rainbow", "heat", "topo",
                                   "spectral", "yellow_red",
                                   "green_blue", "purples"),

                      get_colors = function(name, ncolors=10) {
                        switch(name,
                              "grayscale"=gray(seq(0,1,length.out=ncolors)),
                              "rainbow"=rainbow(ncolors),
                              "heat"=heat.colors(ncolors),
                              "topo"=topo.colors(ncolors),
                              "spectral"=RColorBrewer::brewer.pal(ncolors, "Spectral"),
                              "green_blue"=RColorBrewer::brewer.pal(ncolors, "GnBu"),
                              "yellow_red"=RColorBrewer::brewer.pal(ncolors, "YlOrRd"),
                              "purples"=RColorBrewer::brewer.pal(ncolors, "Purples")
                      )},

                      get_map_names = function() self$map_names
                    )
)


#' @import assertthat
#' @keywords internal
mapToColors <- function (imslice, col = heat.colors(128, alpha = 1), zero_col = "#00000000",
          alpha = 1, irange = range(imslice), threshold = c(0, 0)) {

  assertthat::assert_that(diff(irange) >= 0)
  drange <- diff(irange)
  mcols <- (imslice - irange[1])/diff(irange) * (length(col) -
                                                   1) + 1
  mcols[mcols < 1] <- 1
  mcols[mcols > length(col)] <- length(col)
  imcols <- col[mcols]
  if (!is.vector(imslice)) {
    dim(imcols) <- dim(imslice)
  }
  imcols[imslice == 0] <- zero_col

  if (diff(threshold) > 0) {
    imcols[(imslice >= threshold[1]) & (imslice <= threshold[2])] <- "#00000000"
  }
  if (alpha < 1) {
    rgbmat <- col2rgb(imcols, alpha = TRUE)
    rgbmat <- rgbmat/255
    rgbmat[4, ] <- rgbmat[4, ] * alpha
    if (is.vector(imslice)) {
      array(t(rgbmat), c(length(imslice), 4))
    }
    else {
      array(t(rgbmat), c(dim(imslice), 4))
    }
  }
  else {
    imcols
  }
}





