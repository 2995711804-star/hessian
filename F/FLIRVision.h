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
    void on_Initialize_clicked();//��ʼ�����
    void Configure(CameraPtr pCam);//��ʼ���������

    void on_spinBox_exposure_valueChanged();//�ֶ������ع�
    void on_spinBox_gain_valueChanged();//�ֶ���������
    void on_spinBox_gamma_valueChanged();//�ֶ�����Gamma

    void ImshowCamera();//����ʵʱ��ʾ��Ƶ��
    void on_Pause_clicked();//��ͣ��Ƶ��
    void on_videostreaming_clicked();//����Ƶ��
    void on_Exit_clicked();//�˳�����
    void on_Catchimages_clicked();//����ͼ��
    void on_Piccount_valueChanged();//�ж�ͼ���Ƿ�����
    void on_Groupcount_valueChanged();//�ı�����ͼ��תΪ�����һ��
    void on_Image_clicked();//�鿴�ɼ�����ͼ��

    void on_Trigger_clicked();//����
    void on_singleTrigger_clicked();//���鴥��
    void on_ConfigureTrigger(INodeMap& nodeMap);//��ʼ����������
    void on_Triggerimage_clicked();//�鿴����ͼƬ
    void GrabNextImageByTrigger(INodeMap& nodeMap, CameraPtr pCam);//������һ��ͼ��
    void ResetTrigger(INodeMap& nodeMap);//�رմ�������
    int AcquireImages(CameraPtr pCam, INodeMap& nodeMap);//������ȡͼ��
    int AcquireImagessingle(CameraPtr pCam, INodeMap& nodeMap);//���鴥����ȡͼ��

private:
    Ui::FLIRVisionClass ui;
    SystemPtr system;//���ϵͳ����
    CameraList camList;//����б����
    CameraPtr pCam = nullptr;//���ָ�����
    int q;//������Ƶ����ʼ��ͣ
    Mat frame;
    QDateTime time = QDateTime::currentDateTime();//��ȡϵͳ���ڵ�ʱ��
    QString time_str = time.toString("MM-dd hh:mm:ss");//������ʾ��ʽ
};
