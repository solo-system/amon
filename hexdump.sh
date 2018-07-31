hexdump -n 44 -e '
	1/4 "RIFF: %.4s\n"     
	1/4 "FileSize: %d\n"   
	1/4 "WAVE: %.4s\n"     
	1/4 "fmt0: %s\n"       
	1/4 "datalength: %d\n" 
	1/2 "datatype: %d\n"   
	1/2 "channels: %d\n"   
	1/4 "sampleRate: %d\n"
	1/4 "byterate: %d\n"
	1/2 "bitsperframe: %d\n"
	1/2 "bitspersample: %d\n"
	1/4 "data: %.4s\n"
	1/4 "dataSize: %d\n"
	

	' audio-solo-2018-07-31_20-10-03.wav
