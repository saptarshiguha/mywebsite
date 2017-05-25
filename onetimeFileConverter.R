source("~/prefix.R")

daFile <- "2014-10-25-alemany.md"

x1 <- expression({
file.copy(daFile, sprintf("/tmp/%s",daFile),overwrite=TRUE)
y <- readLines(daFile)
maps <- fread("/tmp/images.csv")
loc=gregexpr('"( |\t)*\\{\\{[( |\t))*site.url[:blank:]*\\}\\}( |\t)*[a-zA-Z /0-9._\\-]+(jpg|jpeg|gif|png)"', y)
getSubs <- function(ii,l,o,oattr){
    aword <- substr(l, o[ii],o[ii]+oattr[ii]-1)
    filename <- gregexpr("[a-zA-Z 0-9._\\-]+(gif|jpeg|jpg|png)", aword)[[1]]
    filename <- substr(aword, filename[[1]], filename[[1]]+attr(filename,"match.length")-1)
    nextpath <- strsplit(gsub("/+","/",aword), "/")[[1]]
    list(filename, nextpath[ length(nextpath)-1],aword )
}
y2 <- Map(function(i, o, l){
    print(i)
    if(length(o)==1 && o[1]<0) return(l)
    oattr <- attr(o, "match.length")
    orig <- l
    for(ii in seq_along(o)){
        print(ii)
        k <- getSubs(ii, l,o, oattr)
        if(k[[2]] == "images") k[[2]] <- "webimages" ## my google folder rewrite
        url <- strsplit(maps[ title==k[[1]] & grepl(k[[2]], parent),url],"&")[[1]][1]
        orig <- gsub(k[[3]], sprintf('"%s"',url), orig, fixed=TRUE)
    }
    return(orig)
}, seq_along(loc), loc,y)
y2 <- unlist(y2)

writeLines(y2, daFile)
})
