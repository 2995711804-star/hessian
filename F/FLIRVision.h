#pragma once

#include <QtWidgets/QMainWindow>
#include "ui_FLIRVision.h"
#include <Spinnaker.h>
#include <SpinGenApi/SpinnakerGenApi.h>
#include <iostream>
#include <sstream>
#include <opencv2/opencv.hpp>
#include <qlabel.h>
#include <qimage.h>
#include <qpixmap.h>
#include <qtimer.h>
#include <string>
#include <fstream>
#include <QFileDialog>
#include <QDesktopServices>
#include <QMouseEvent>
#include <QFileDialog>
#include <QTime>
#include <fstream>

using namespace Spinnaker;
using namespace Spinnaker::GenApi;
using namespace Spinnaker::GenICam;
using namespace std;
using namespace cv;

class FLIRVision : public QMainWindow
{
    Q_OBJECT

public:
    FLIRVision(QWidget *parent = nullptr);
    ~FLIRVision();

public slots:
    void on_Initialize_clicked();//初始化相机
    void Configure(CameraPtr pCam);//初始化相机配置

    void on_spinBox_exposure_valueChanged();//手动调节曝光
    void on_spinBox_gain_valueChanged();//手动调节增益
    void on_spinBox_gamma_valueChanged();//手动调节Gamma

    void ImshowCamera();//窗口实时显示视频流
    void on_Pause_clicked();//暂停视频流
    void on_videostreaming_clicked();//打开视频流
    void on_Exit_clicked();//退出程序
    void on_Catchimages_clicked();//捕获图像
    void on_Piccount_valueChanged();//判断图像是否拍摄
    void on_Groupcount_valueChanged();//改变组数图像转为改组第一张
    void on_Image_clicked();//查看采集到的图像

    void on_Trigger_clicked();//触发
    void on_singleTrigger_clicked();//单组触发
    void on_ConfigureTrigger(INodeMap& nodeMap);//初始化触发配置
    void on_Triggerimage_clicked();//查看触发图片
    void GrabNextImageByTrigger(INodeMap& nodeMap, CameraPtr pCam);//捕获下一张图像
    void ResetTrigger(INodeMap& nodeMap);//关闭触发功能
    int AcquireImages(CameraPtr pCam, INodeMap& nodeMap);//触发获取图像
    int AcquireImagessingle(CameraPtr pCam, INodeMap& nodeMap);//单组触发获取图像

private:
    Ui::FLIRVisionClass ui;
    SystemPtr system;//相机系统变量
    CameraList camList;//相机列表变量
    CameraPtr pCam = nullptr;//相机指针变量
    int q;//控制视频流开始暂停
    Mat frame;
    QDateTime time = QDateTime::currentDateTime();//获取系统现在的时间
    QString time_str = time.toString("MM-dd hh:mm:ss");//设置显示格式
};
