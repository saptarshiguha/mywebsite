library(infuser)
library(colorout)
library(data.table)
options(width=250)

makePB <- function(l){
    require(progress)
    progress_bar$new(format = "Processing (:extra) [:bar] :percent (:current / :total) elapsed: :elapsed eta: :eta"
                          ,total = l, clear = FALSE, width= 60)
}

RM <- function(s){
    print(s)
    strsplit(s,"&export=download")[[1]][[1]]
}


## Store your pictures in a folder in gdrive e.g.  webimages/photos/idleaway
## Wait for them to upload
## Edit imageFileRep.py  and set 'bp' to the name of the folder (idleaway)
## run the code which will save filenames to "/tmp/images.csv"
## switch to the folder  webimages/photos/idleaway
## and run the following code
pto <- "2017-jan-30"
system(sprintf("python ~/saptarshiguha.github.io/imageFileRep.py %s", pto))
pat <- "/tmp/images.csv"
files <- fread(pat)
files$id <- 1:nrow(files)
files[, prefix:= unlist(lapply(strsplit(title,"-"),"[[",1))]
files[, sizetype:= sapply(title, function(s) if(grepl("-(brd|bord)", s)) "brd" else "full")]


useBorderAsURL <- TRUE
newurls <- files[,{
    hasFullImage <- length((url[sizetype %in% c('full','sml')]))>0
    y <- if(hasFullImage) {
             fullglink <- RM(url[sizetype %in% c('full','sml')])
             '{{fullglink}} {{smallglink}}'
         }else if(useBorderAsURL){
             fullglink <- RM(url[sizetype %in% c("bord","brd")])
             '{{fullglink}} {{smallglink}}'
         }else{
             fullglink <- ""
             '{{smallglink}}'
         }
    yt <- infuse(y, list(fullglink=fullglink, smallglink=RM(url[sizetype=="brd"])))
    list(newurl=yt)
},by=prefix]

y <- sprintf("%s\n",paste(newurls$newurl,collapse="\n"))
clip <- pipe("pbcopy", "w") ; writeLines(y, con=clip); close(clip)
y


