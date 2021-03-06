# Last Change: Fri Jul 25 02:44:20 PM 2014 CDT

#options(echo=TRUE) # if you want see commands in output file
args <- commandArgs(trailingOnly = TRUE)
#print(args)
# trailingOnly=TRUE means that only your arguments are returned, check:
# print(commandsArgs(trailingOnly=FALSE))

file <- args[1]
output <- args[2]

data <- read.table(file,sep="\t",colClasses=c("character","numeric","character","character","numeric","character","numeric","character","numeric","character","numeric","character","numeric"))

#require 10x of depth to make a call
data = data[rowSums(data[,c(5,7,9,11)])>=10,]
if(length(data[,1]) < 1){
  stop("ERROR: no site has greater than 10x coverage");
}

for (i in 1:nrow(data)) {
	counter <- 0; alpha <- c(NA,NA); num <- c(0,0)
	for (j in seq(5,11,2)) {
		if (data[i,j] > 5) {
		counter <- counter + 1
		alpha[counter] <- data[i,j-1]
		num[counter] <- data[i,j]
		}
	}
	if (num[1] >= 12 & num[2] == 0) {
		data[i,14] <- alpha[1]
	}
	if (counter == 2 & (num[1] + num[2]) >= 12) {
		total <- num[1] + num[2]; half <- round((num[1] + num[2])/2)
		p1 <- fisher.test(rbind(c(num[1],num[2]),c(total,0)), alternative="two.sided", conf.level=0.95)$p.value
		p2 <- fisher.test(rbind(c(num[1],num[2]),c(0,total)), alternative="two.sided", conf.level=0.95)$p.value
		p3 <- fisher.test(rbind(c(num[1],num[2]),c(half,half)), alternative="two.sided", conf.level=0.95)$p.value
		if (p1 >= p2 & p1 >= p3) {
			data[i,14] <- alpha[1]
		}
		if (p2 >= p1 & p2 >= p3) {
			data[i,14] <- alpha[2]
		}
		if (p3 >= p1 & p3 >= p2) {
			data[i,14] <- paste(alpha[1],alpha[2],sep="/")
		}
	}
}

write.table(data,file=output,row.names=F,col.names=F,quote=F,sep="\t")



