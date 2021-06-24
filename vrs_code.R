# Load required packages:
library(sf)
library(terrainr)
library(raster)
library(rgrass7)
# Creating a point representing the lodge location
# Create a table with point coordinates:
coords <- data.frame(y = 44.1585, x = -73.8624)
# Transform it into an "sf" object:
lodge_coords <- st_as_sf(coords,  coords = c("x", "y"))
# Assign it the WGS84 CRS (EPSG 4326):
lodge_coords <- st_set_crs(lodge_coords, 4326)
# Create a square centered on this point, with sides 12,200 meters long:
lodge_bbox <- set_bbox_side_length(lodge_coords, 12200)
# Use terrainr to download DEMs and orthoimagery from the USGS:
lodge_tiles <- get_tiles(lodge_bbox,
                         "johns_brook",
                         services = c("elevation", "ortho"))
# Merge the tiles returned by the USGS into individual raster files:
merge_rasters(lodge_tiles$elevation, "merged_johns_brook_dem.tif")
merge_rasters(lodge_tiles$ortho, "merged_johns_brook_ortho.tif")
# Create an overlay for Unity containing our central point as a red dot:
vector_to_overlay(lodge_coords,
                  "merged_johns_brook_dem.tif",
                  color = "red",
                  size = 10,
                  output_file = "point_location.tiff")
# Transform our elevation raster into heightmaps for input into Unity:
raster_to_raw_tiles("merged_johns_brook_dem.tif", "heightmap")
# Transform our overlays into map tiles for input:
raster_to_raw_tiles("merged_johns_brook_ortho.tif", "ortho", raw = FALSE)
raster_to_raw_tiles("point_location.tiff", "point", raw = FALSE)
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
          memory=1000,
          output="viewshed")
# Save our viewshed raster to file
execGRASS("r.out.gdal",
          c("t", "m", "overwrite"),
          input="viewshed",
          output="viewshed.tif",
          format="GTiff",
          createopt="TFW=YES,COMPRESS=LZW")
# Load our viewshed raster
viewshed <- raster("viewshed.tif")
# Create a multi-band image from our single-band raster
# and set visible areas to transparent
alpha <- viewshed == 0
viewshed <- brick(viewshed, viewshed, viewshed, alpha)
# Save the viewshed raster
writeRaster(viewshed, "viewshed_image.tif", overwrite = TRUE)
# Transform the viewshed into tiles:
raster_to_raw_tiles("viewshed_image.tif", "viewshed", raw = FALSE)
