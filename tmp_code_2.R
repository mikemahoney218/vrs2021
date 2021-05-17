# Load required packages:
library(terrainr)
library(raster)
library(rgrass7)
# Initialize GRASS GIS
initGRASS(system("grass --config path", intern = TRUE),
          raster::tmpDir(),
          mapset = "PERMANENT",
          override = TRUE)
# Set our CRS equal to that of our merged elevation raster
execGRASS("g.proj",
          "c",
          georef = "merged_johns_brook_dem.tif")
# Read our elevation raster into the GRASS session
execGRASS("r.in.gdal",
          c("overwrite", "o"),
          input="merged_johns_brook_dem.tif",
          band=1,
          output="elevation")
# Specify the region we want covered by the viewshed
execGRASS("g.region",
          raster="elevation")
# Calculate the viewshed
execGRASS("r.viewshed",
          c("b", "overwrite"),
          input="elevation",
          coordinates=c(coords$x, coords$y),
          memory=500,
          output="viewshed")
# Save our viewshed raster to file
execGRASS("r.out.gdal",
          c("t", "m", "overwrite"),
          input="viewshed",
          output="viewshed.tif",
          format="GTiff",
          createopt="TFW=YES,COMPRESS=LZW")
# Load our viewshed raster and set visible areas to transparent
viewshed <- raster::raster("r_viewshed.tif")
viewshed[viewshed > 0] <- NA
# Save the viewshed raster
writeRaster(viewshed, "viewshed_image.tiff", overwrite = TRUE)
# Transform the viewshed into tiles:
raster_to_raw_tiles("viewshed_image.tiff", "viewshed", raw = FALSE)