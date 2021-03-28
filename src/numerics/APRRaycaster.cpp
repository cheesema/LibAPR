
#include "APRRaycaster.hpp"
#include "vis/Camera.h"
#include "vis/Object.h"
#include "vis/RaytracedObject.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Implementation of glm related stuff. Main reason is to avoid necessity to have glm header files installed
// to use libAPR.

struct APRRaycaster::GlmObjectsContainer {
    RaytracedObject raytracedObject;
    glm::mat4 mvp;
};

void APRRaycaster::initObjects(int imageWidth, int imageHeight, float radius, float theta, float x0, float y0,
                               float z0, float x0f, float y0f, float z0f, float phi_) {
    Camera cam = Camera(glm::vec3(x0 + radius*sin(phi), y0 + radius * sin(theta)*cos(phi_s), z0 + radius * cos(theta)*cos(phi_s)),
                        glm::fquat(1.0f, 0.0f, 0.0f, 0.0f));
    cam.setTargeted(glm::vec3(x0f, y0f, z0f));
    cam.setPerspectiveCamera((float) imageWidth / (float) imageHeight, (float) (60.0f / 180.0f * M_PI), 0.5f, 70.0f);
    glmObjects = new GlmObjectsContainer{
            RaytracedObject(glm::vec3(0.0f, 0.0f, 0.0f), glm::fquat(1.0f, 0.0f, 0.0f, 0.0f)),
            glm::mat4((*cam.getProjection()) * (*cam.getView()))
    };
}

void APRRaycaster::killObjects() {
    delete glmObjects;
    glmObjects = nullptr;
}

void
APRRaycaster::getPos(int &dim1, int &dim2, float x_actual, float y_actual, float z_actual, int x_num, int y_num) {
    glm::vec2 pos = glmObjects->raytracedObject.worldToScreen(glmObjects->mvp, glm::vec3(x_actual, y_actual, z_actual),
                                                              x_num, y_num);
    dim1 = round(-pos.y);
    dim2 = round(-pos.x);
}
