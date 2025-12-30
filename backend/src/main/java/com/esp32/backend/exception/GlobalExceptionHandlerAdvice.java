package com.esp32.backend.exception;

import com.esp32.backend.pojo.ResponseMessage;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandlerAdvice {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandlerAdvice.class);

    @ExceptionHandler({Exception.class})
    public ResponseMessage handleException(Exception e, HttpServletRequest request, HttpServletResponse response) {
        log.error("" + e);
        return new ResponseMessage(500,"Error",null);
    }

}
