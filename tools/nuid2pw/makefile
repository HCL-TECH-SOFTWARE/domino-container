
NAME=nuid2pw

$(NAME): $(NAME).o
	g++ -o $(NAME) $(NAME).o

$(NAME).o: $(NAME).c
	g++ -c -m64 $(NAME).c

clean:
	rm $(NAME) $(NAME).o

update:
	mv $(NAME) ../../dockerfiles/domino/install_dir/
	rm $(NAME).o
