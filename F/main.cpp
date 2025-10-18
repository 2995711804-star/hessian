#include "FLIRVision.h"
#include <QtWidgets/QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    FLIRVision w;
    w.show();
    return a.exec();
}
