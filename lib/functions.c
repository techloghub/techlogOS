#include "functions.h"

void clear_screen() {
    char blank[50], i;
    for (i = 0; i < 50; ++i) {
        if (i == 48) {
            blank[i] = '\n';
            blank[i + 1] = '\0';
            break;
        } else {
            blank[i] = ' ';
        }
    }
    for (i = 0; i < 80; ++i) {
        print(blank);
    }
    disp_pos = 0;
}

char* itoa(char *str, int num) {
    char *p = str;
    char ch;
    int i;
    int flag = 0;

    *p++ = '0';
    *p++ = 'x';

    if (num == 0) {
        *p++ = '0';
    } else {
        for (i = 28; i >= 0; i -= 4) {
            ch = (num >> i) & 0xF;
            if (flag || (ch > 0)) {
                flag = 1;
                ch += '0';
                if (ch > '9') {
                    ch += 7;
                }
                *p++ = ch;
            }
        }
    }

    *p = 0;
    return str;
}

void print(char *str) {
    print_with_color(str, 15);
}

void print_with_color(char *str, int color) {
    char *p = str;
    while (*p != '\0') {
        if (*p == '\n') {
            disp_pos = (disp_pos/160 + 1) * 160;
            p++;
            continue;
        }
        disp_char(p, color);
        disp_pos += 2;
        p++;
    }
}

void disp_int(int input) {
	char output[16];
	itoa(output, input);
	print(output);
}
