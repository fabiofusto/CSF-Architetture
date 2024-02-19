# Correlation Feature Selection algorithm

Created by Francesco Bongiovanni, Simone Caridà and Fabio Fusto

## Description

This is an algorithm written in C, Assembly x86-32+SSE, x86-64+AVX and openMP. The goal of this project was to achieve the lowest possible execution time and compete with other students. The project outline is in Italian only.
Search "Correlation Feature Selection" for major details.

## Usage

You can run the project using the attached test files and specifying the architecture you want to use (32 or 64) with this command:
```bash
./run<ARCH> -ds "test_5000_50_<ARCH>.ds" -labels "test_5000_50_<ARCH>.labels" -k 5 -d
```
Feel free to contact me to have more test files.

## Contributing

Pull requests are welcome because this project is not perfect.
There are some problems in the Assembly procedures when using datasets with an odd number of rows.
For major changes, please open an issue first to discuss what you would like to change.
