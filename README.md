# ShinyCell as a Docker image

**This is a fork of the original ShinyCell:** https://github.com/VCCRI/ShinyCell.
This repository only adds minor infrastructure to build a Docker image of ShinyCell, so that it can be invoked simply, e.g.,

``` bash
# In this project root, build the Docker image
docker build -t shinycell .
# Run it where you like. Replace /path/to/seurat/files and your_object.rds accordingly. 
docker run --rm -it -p 3838:3838 \
  -v /path/to/seurat/files:/data shinycell your_object.rds
```
