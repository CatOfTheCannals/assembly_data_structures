#include "lib.h"

/** STRING **/

char* strRange(char* a, uint32_t i, uint32_t f) {
    // TODO: output file is not correct
    if(i > f) return a;
   
    char *ret;
 
    uint32_t n = strLen(a);
    if(i > n - 1) {
        free(a);
        ret = malloc(1);
        ret[0] = 0;
        return ret;   
    }

    if(f > n - 1) f = n - 1;

    uint32_t retLen = f - i + 2;
    ret = malloc(retLen);

    for(uint32_t index = 0; index < retLen - 1; index ++) {
        ret[index] = a[index + i];
    }
    ret[retLen - 1] = 0;

    free(a);
    return ret;
}

/** Lista **/

void listPrintReverse(list_t* l, FILE *pFile, funcPrint_t* fp) {
    fprintf(pFile, "[");
    listElem_t *currNode = l->last;

    if(fp == NULL) {
        while(currNode != NULL) {
            fprintf(pFile, "%p", currNode->data);
            currNode = currNode->prev;
            if(currNode != NULL) fprintf(pFile, ",");
        }
    } else {
        while(currNode != NULL) {
            fp(currNode->data, pFile);
            currNode = currNode->prev;
            if(currNode != NULL) fprintf(pFile, ",");
        }
    }    
    fprintf(pFile, "]");    
}

/** n3tree **/

void n3treePrintAux(n3treeElem_t* t, FILE *pFile, funcPrint_t* fp) {
    if(!t) return;

    // try left recur call
    if(t->left) {
        n3treePrintAux(t->left, pFile, fp);
    }

    // print node data 
    if(!fp) {
        fprintf(pFile, "%p ", t->data);
    } else {
        fp(t->data, pFile);
    }

    // print list
    if(t->center) {
        if(t->center->first) {
            listPrint(t->center, pFile, fp);
        }
    }
    fprintf(pFile, " ");

    // try right recur call
    if(t->right) {
        n3treePrintAux(t->right, pFile, fp);
    }

}

void n3treePrint(n3tree_t* t, FILE *pFile, funcPrint_t* fp) {
    fprintf(pFile, "<< ");
    
    n3treePrintAux(t->first, pFile, fp);

    fprintf(pFile, ">>");
}

/** nTable **/

void nTableRemoveAll(nTable_t* t, void* data, funcCmp_t* fc, funcDelete_t* fd) {
    uint32_t i = 0;
    while(i < t->size) {
        nTableRemoveSlot(t, i, data, fc, fd); 
        i++;
    }
}

void nTablePrint(nTable_t* t, FILE *pFile, funcPrint_t* fp) {
    uint32_t i = 0;
    while(i < t->size) {
        list_t *l = t->listArray[i];
        fprintf(pFile, "%d = ", i);   
        listPrint(l, pFile, fp);
        fprintf(pFile, "\n");
        i++;
    }
}
