
library(infuser)
library(colorout)
library(data.table)
options(width=250)


RM <- function(s){
    if(length(s)>0) strsplit(s,"&export=download")[[1]][[1]]
}


## Store your pictures in a folder in gdrive e.g.  webimages/photos/idleaway
## Wait for them to upload
## run the code which will save filenames to "/tmp/images.csv"
## switch to the folder  webimages/photos/idleaway
## and run the following code
## pto is of the form 'YYYY-MM-DD'
## if you see different because this system was only implemented 02/21/2017 onwrds

pto <- "2017-05-08"
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

#makepost=TRUE
if(!makepost) stop("ending without making  post")

y2 <- paste(unlist(lapply(U <- strsplit(newurls$newurl," "),"[[",1)),collapse="\n")
template <- "---
layout: postjournal
title: A collection of photos from now and then 
excerpt: %s pictures posted automatically
tags: misc
---

{%%  jrnl  %%}
{%% swirl %%}

{%% imgtile nc=1 w=12 %%}
%s
{%% endimgtile %%}

{%% endjrnl %%}
"

template2 <- sprintf(template, length(U), y2)
rnd <- sample(1:1000,1)
#rnd <- 197
posttitle <- sprintf("_posts/%s-newpost-%s.md", pto,rnd )
writeLines(template2, posttitle)
system("jekyll build && syncweb")
