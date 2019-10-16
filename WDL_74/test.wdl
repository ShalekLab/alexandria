workflow w {
	
	String dir
	String dir2
	
	call t {
		input:
			dir=sub(dir, "/+$", "/"),
			dir2=sub(dir2, "/+$", "/")
	}
}

task t {
	
	String dir
	String dir2
	
	command {
		echo ${dir2}${dir}${dir2}${dir}${dir2}
	}
	
}