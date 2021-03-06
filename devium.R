
#debugging  stopped working/updating?
#-------------------
app.state<-reactive({
	obj<-get(input$debug_object)
	str(obj[[input$debug_name]])
	cat("------------------------\n")
	obj[[input$debug_name]]
})

ui_Debug<-function(){
	list(
		selectInput(inputId = "debug_object", label = "Object", choices = c("input","values"), selected = "input", multiple = FALSE),
		selectInput(inputId = "debug_name", label = "Name", choices = "", multiple = FALSE)
	)
} 

debug.names<-reactive({
	
	tryCatch(names(get(input$debug_object)),error=function(e){return()})

})

observe({
	updateSelectInput(session, "debug_name", choices = debug.names() )
})

#debugging  print all names and values in input
output$debug<- renderPrint({
	if(is.null(input)) return()
	# if(input$debug_action==0) return()
	# obj<-names(input)
	# input.obj<-lapply(1:length(obj), function(i) { input[[obj[i]]]})
	# names(input.obj)<-obj
	# obj<-names(values)
	# values.obj<-lapply(1:length(obj), function(i) { values[[obj[i]]]})
	# names(values.obj)<-obj
	app.state()
})

#function to copy all contents of input
copy.input<-function(){
	obj<-tryCatch(names(get("input")),error=function(e){return()})
	input.obj<-lapply(1:length(obj), function(i) { input[[obj[i]]]})
	names(input.obj)<-obj
	return(input.obj)
}


#helper for data transposing mechanism, which was a horrible idea!
rdy.t<-function(obj){
  list<-dimnames(obj)
  names<-lapply(seq(list), function(i){
    tmp<-check.fix.names(fixlc(list[[i]]),ok.chars=c(".","_"))
    test<-!is.na(as.numeric(tmp))
    paste(ifelse(test,"X",""),tmp,sep="")           
  })
  out<-as.data.frame(obj)
  dimnames(out)<-names
  return(data.frame(out))
}

################################################################
# functions used in radyant
################################################################
varnames2 <- function() {
	if(is.null(input$datasets)) return()

	dat <- getdata2()
	cols <- colnames(dat)
	names(cols) <- paste(cols, " {", sapply(dat,class), "}", sep = "")
	cols
}

changedata <- function(addCol = NULL, addColName = "") {
	# function that changes data as needed
	if(is.null(addCol) || addColName == "") return()
  # We don't want to take a reactive dependency on anything
  isolate({
  	values[[input$datasets]][,addColName] <- addCol
  })
}

changedataRows <- function(addRow = NULL, addRowName = "") {
	# function that changes data as needed
	if(is.null(addRow) || addRowName == "") return()
  # We don't want to take a reactive dependency on anything
  isolate({
  	values[[input$datasets]][addRowName,] <- addRow
  })
}

getdata <- function(dataset = input$datasets) {
  values[[dataset]]
}	

getdata2 <- function(dataset = input$datasets) {  #used for transposable data fxns
  rdy.t(values[[input$datasets]])
}	

loadUserData <- function(uFile) {

	ext <- file_ext(uFile) 
	objname <- robjname <- sub(paste(".",ext,sep = ""),"",basename(uFile))
	ext <- tolower(ext)

	if(ext == 'rda' || ext == 'rdata') {
		# objname will hold the name of the object inside the R datafile
	  objname <- robjname <- load(uFile)
		values[[robjname]] <- get(robjname)
	}

	if(datasets[1] == '') {
		datasets <<- c(objname)
	} else {
		datasets <<- unique(c(objname,datasets))
	}

	if(ext == 'sav') {
		values[[objname]] <- read.sav(uFile)
	} else if(ext == 'dta') {
		values[[objname]] <- read.dta(uFile)
	} else if(ext == 'csv') {
		values[[objname]] <- read.csv(uFile)
	}
	datasets <<- unique(c(robjname,datasets))
}

loadPackData <- function(pFile) {

	robjname <- data(list = pFile)
	dat <- get(robjname)

	if(pFile != robjname) return("R-object not found. Please choose another dataset")

	if(is.null(ncol(dat))) {
		# values[[packDataSets]] <- packDataSets[-which(packDataSets == pFile)]
		return()
	}

	values[[robjname]] <- dat

	if(datasets[1] == '') {
		datasets <<- c(robjname)
	} else {
		datasets <<- unique(c(robjname,datasets))
	}
}

#################################################
# reactive functions used in radyant
#################################################

uploadfunc <- reactive({

  # if(input$upload == 0) return("")
 	# fpath <- try(file.choose(), silent = TRUE)
 	# if(is(fpath, 'try-error')) {
  # 	return("")
  # } else {
  # 	return(fpath)
  # }
	
 	values$fpath <- ""
	if(!is.null(input$upload)){ #***
		if (interactive() == TRUE) {
		if (input$upload != 0) {
			fpath <- try(file.choose(), silent=TRUE)
			if(is(fpath, 'try-error')) values$fpath <- "" else values$fpath<-fpath
			
		}
		} else {
		if (!is.null(input$serv_upload) && nrow(input$serv_upload) != 0) {
			values$fpath <- input$serv_upload[1,'datapath']
			# values$fpath <- ""
		  }
		}
	}
  values$fpath
})

output$upload_local_server <- renderUI({ # data upload function

	if (interactive() == TRUE) {
	  actionButton("upload", "Choose a file") # doesn't seem to do anything?
	} else {
	  fileInput('serv_upload','')
	}
  # read.csv(input$file2server$data)
	# fpath <- uploadfunc()
 	# fileInput('file2server', 'Choose a file')
  # if (is.null(input$file2server)) return("")

})

output$downloadData <- downloadHandler(
	filename = function() { paste(input$datasets[1],'.',input$saveAs, sep='') },
  content = function(file) {

	  ext <- input$saveAs
	  robj <- input$datasets[1]
	  assign(robj, getdata())

		if(ext == 'rda' || ext == 'rdata') {
	    save(list = robj, file = file)
		} 
		else if(ext == 'dta') {
			write.dta(get(robj), file)
		} else if(ext == 'csv') {
			write.csv(get(robj), file)
		}
  }
)

output$datasets <- renderUI({

	fpath <- uploadfunc()
	# loading user data
	if(fpath != "" ) loadUserData(fpath)
	

	# # loading package data
	# if(input$packData != "") {
		# if(input$packData != lastLoaded) {
			# loadPackData(input$packData)
			# lastLoaded <<- input$packData 
		# }
	# }
	# Drop-down selection of data set
	selectInput(inputId = "datasets", label = "Datasets:", choices = datasets, selected = datasets[1], multiple = FALSE)
	# selectInput(inputId = "datasets", label = "Datasets:", choices = values$datasetlist, selected = values$datasetlist[1], multiple = FALSE)
})

output$packData <- renderUI({
	selectInput(inputId = "packData", label = "Load package data:", choices = packDataSets, selected = '', multiple = FALSE)
})

output$columns <- renderUI({
	cols <- varnames()
	selectInput("columns", "Select columns to show:", choices  = as.list(cols), selected = names(cols), multiple = TRUE)
})

output$nrRows <- renderUI({
	if(is.null(input$datasets)) return()
	dat <- getdata()

	# number of observations to show in dataview
	nr <- nrow(dat)
	sliderInput("nrRows", "Rows to show (max 50):", min = 1, max = nr, value = min(15,nr), step = 1)
})

################################################################
# Data reactives - view, plot, transform data, and log your work
################################################################
output$dataviewer <- renderTable({
	if(is.null(input$datasets) || is.null(input$columns)) return()

	dat <- getdata()

	# not sure why this is needed when files change ... but it is
	# without it you will get errors the invalid columns have been
	# selected
	if(!all(input$columns %in% colnames(dat))) return()

	if(!is.null(input$sub_select) && !input$sub_select == 0) {
		isolate({
			if(input$dv_select != '') {
				selcom <- input$dv_select
				selcom <- gsub(" ", "", selcom)
				if(nchar(selcom) > 30) q()
				if(length(grep("system",selcom)) > 0) q()
				if(length(grep("rm\\(list",selcom)) > 0) q()
					
				# use sendmail from the sendmailR package	-- sendmail('','vnijs@rady.ucsd.edu','test','test')
				# first checking if selcom is a valid expression
				parse_selcom <- try(parse(text = selcom)[[1]], silent = TRUE)
				if(!is(parse_selcom, 'try-error')) {
					seldat <- try(eval(parse(text = paste("subset(dat,",selcom,")")[[1]])), silent = TRUE)
					if(is.data.frame(seldat)) {
						return(seldat[, input$columns, drop = FALSE])
					}
				} 
			}
		})
	}

	# Show only the selected columns and no more than 50 rows at a time
	nr <- min(input$nrRows,nrow(dat))
	data.frame(dat[max(1,nr-50):nr, input$columns, drop = FALSE])

})

################################################################
# Output controls for the Summary, Plots, and Extra tabs
# The tabs are re-used for various tools. Depending on the tool
# selected by the user the appropriate analysis function 
# is called.
# Naming conventions: The reactive function to be put in the
# code block above must be of the same name as the tool
# in the tools drop-down. See global.R for the current list
# of tools (and tool-names) 
################################################################


### Creating dynamic tabsets - From Alex Brown

# Generate output for the summary tab
# output$summary <- renderUI(function() {
output$summary <- renderPrint({
	if(is.null(input$datasets) || input$tool == 'dataview') return()

	# get the summary function for currenly selected tool and feed
	# it the output from one of the analysis reactives above
	# get-function structure is used because there may be a large
	# set of tools that will have the same output structure
	f <- get(paste("summary",input$tool,sep = '.'))
	result <- get(input$tool)()
	if(is.character(result)) {
		cat(result,"\n")
	} else {
		f(result)
	}
})

# Generate output for the plots tab
output$plots <- renderPlot({
	
	# plotting could be expensive so only done when tab is being viewed
	if(input$tool == 'dataview' || input$analysistabs != 'Plots') return()

	f <- get(paste("plot",input$tool,sep = '.'))
	result <- get(input$tool)()
	if(!is.character(result)) {
		f(result)
	} else {
		plot(x = 1, type = 'n', main="No variable selection made", axes = FALSE, xlab = "", ylab = "")
	}
}, width=700, height=700)

#controls for plotting tab
# Generate output for the plots tab
output$plot_control <- renderUI({

	# plotting could be expensive so only done when tab is being viewed
	if(input$tool == 'dataview' || input$analysistabs != 'Plots') return()

	out<-get(paste("plot_control",input$tool,sep = '.'))()
	if(exists("out")){out}
})
