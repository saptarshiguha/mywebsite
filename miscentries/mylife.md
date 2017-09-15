---
layout: post
title: Using Terra to Speed Up R
excerpt: Exploring the new TerraLang project as an extension language for R
tags: terra R performance extension
---

{{ page.title }}
================
<div class="pdate"> {{ page.date | date: "%b %d, %Y" }} </div>


[My helpful screenshot]({{ site.url }}/assets/screenshot.jpg)

<p class="meta">22 Nov 2011 - San Francisco</p>

<pre><code class="R"> 
LY <- which(as.Date(adi$date)>=lastYear)
level.data <- T(MODEL$x[1,])
level.data <- data.frame(date=adi[LY,"date"], y= level.data[LY])

LY <- which(as.Date(adi$date)>=lastYear)
level.data <- T(MODEL$x[1,])
level.data <- data.frame(date=adi[LY,"date"], y= level.data[LY])
level.data$onedate <- sapply(as.Date(level.data$date),function(r){
  if(r>=thisYear) sprintf("2012-%s-%s", strftime(r,"%m"),strftime(r,"%d")) else as.character(r)
})
level.data$whichyear <- sapply(as.Date(level.data$date),strftime, "%Y")
d1 <- lapply(split(level.data,level.data$whichyear),function(r) {
  data.frame(date=r$date, onedate=r$onedate,y=filter(r$y, c(1,1)/2,sides=1))
})
d2 <- merge(d1[[2]],d1[[1]],by="onedate")[,c("onedate","date.x","y.x","y.y")];colnames(d2) <- c("onedate","date","levelTY","levelLY")
d2$y <- 100*(d2$levelTY/d2$levelLY-1)
d2$whichyear <-CODE <- "ThisYear/LastYear"
d3 <- d2[,c("date","y","onedate","whichyear")]
d4 <- rbind(level.data, d3)
ylims <- range(subset(d4, whichyear !=CODE)$y)+c(-1,1)*diff(range(subset(d4, whichyear !=CODE)$y))*0.1/2
ylims <- list(ylims, ylims, range(d2$y,na.rm=TRUE)+c(-1,1)*diff(range(d2$y,na.rm=TRUE))*0.1/2)
lp <- mplot(d4,ylab='Level (millions)',ylims=ylims,panels=3)
</code></pre>

