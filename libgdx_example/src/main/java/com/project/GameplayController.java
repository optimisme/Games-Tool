package com.project;

public interface GameplayController {
    void handleInput();

    void fixedUpdate(float dtSeconds);

    boolean hasCameraTarget();

    float getCameraTargetX();

    float getCameraTargetY();
}
