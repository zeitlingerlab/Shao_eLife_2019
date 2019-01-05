## Script for loading samples

sample_list <- read.csv("/data/sample_summary.csv", header = T, stringsAsFactors = F)

load_bigwig <- function(name, sample_format = "default"){
  if (!(name %in% sample_list$sample_name)){
    message("No sample found, please make sure samples are entered correctly in the /data/sample_summary.csv spreadsheet")
    return(FALSE) 
  } else {
    if (sample_format == "default"){
      sample_path <- list(pos =  as.character(subset(sample_list, sample_name == name)$bigwig_positive),
                          neg =  as.character(subset(sample_list, sample_name ==name)$bigwig_negative))
    }else{
      if (sample_format %in% c("GRanges", "RleList", "NumericList")){
        sample_path <- list(pos =  import(as.character(subset(sample_list, sample_name == name)$bigwig_positive), as= sample_format),
                            neg =  import(as.character(subset(sample_list, sample_name ==name)$bigwig_negative), as= sample_format))

      }else{
        message("sample_format should be 'default', 'GRanges', 'RleList' or 'NumericList'")
        return(FALSE)
      }
    }
  }
  sample_path
}
