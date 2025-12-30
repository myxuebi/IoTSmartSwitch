package com.esp32.backend.controller;

import com.alibaba.fastjson.JSONObject;
import com.esp32.backend.pojo.ResponseMessage;
import com.esp32.backend.pojo.dto.LoginInfoDto;
import com.esp32.backend.utils.JwtTokenUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Objects;

@RestController
@RequestMapping("/api")
public class MainController {

    @Value("${value.user.username}")
    private String profileUsername;

    @Value("${value.user.password}")
    private String profilePassword;

    @Autowired
    private JwtTokenUtil jwtTokenUtil;

    private JSONObject deviceStatus = new JSONObject();

    private JSONObject nowDeviceStatus = new JSONObject();

    @PostMapping("/login")
    public ResponseMessage<JSONObject> login(@RequestBody LoginInfoDto loginInfoDto){
        String username = loginInfoDto.getUsername();
        String password = loginInfoDto.getPassword();
        JSONObject jsonObject = new JSONObject();
        if (Objects.equals(username, profileUsername) && Objects.equals(password,profilePassword)){
//            UUID uuid = UUID.randomUUID();
            String token = jwtTokenUtil.generateToken();
            jsonObject.put("token",token);
            return new ResponseMessage(HttpStatus.OK.value(), "success", jsonObject);
        }else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Unauthorized",null);
        }
    }

    @GetMapping("/checkToken")
    public ResponseMessage<JSONObject> checkToken(@RequestHeader String token){
        JSONObject jsonObject = new JSONObject();
        boolean isValid = jwtTokenUtil.validateToken(token);
        jsonObject.put("isValid", isValid);
        if (isValid) {
            return new ResponseMessage(HttpStatus.OK.value(), "Token is valid", jsonObject);
        } else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Token is invalid", jsonObject);
        }
    }

    @PostMapping("/esp32/nowDeviceStatus")
    public ResponseMessage<JSONObject> esp32NowStatus(@RequestHeader String token, @RequestBody JSONObject status) {
        JSONObject jsonObject = new JSONObject();
        boolean isValid = jwtTokenUtil.validateToken(token);
        if (isValid) {
            nowDeviceStatus.putAll(status);
            return new ResponseMessage(HttpStatus.OK.value(), "success", nowDeviceStatus);
        } else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Token is invalid", jsonObject);
        }
    }

    @GetMapping("/esp32/getDeviceStatus")
    public ResponseMessage<JSONObject> esp32GetStatus(@RequestHeader String token) {
        JSONObject jsonObject = new JSONObject();
        boolean isValid = jwtTokenUtil.validateToken(token);
        if (isValid) {
            if (deviceStatus.isEmpty()) {
                return new ResponseMessage(HttpStatus.OK.value(), "success-null", deviceStatus);
            }else{
                return new ResponseMessage(HttpStatus.OK.value(), "success", deviceStatus);
            }
        } else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Token is invalid", jsonObject);
        }
    }

    @PostMapping("/user/setDeviceStatus")
    public ResponseMessage<JSONObject> setStatus(@RequestHeader String token, @RequestBody JSONObject status) {
        JSONObject jsonObject = new JSONObject();
        boolean isValid = jwtTokenUtil.validateToken(token);
        if (isValid) {
            deviceStatus.putAll(status);
            return new ResponseMessage(HttpStatus.OK.value(), "success", deviceStatus);
        } else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Token is invalid", jsonObject);
        }
    }

    @GetMapping("/user/getDeviceStatus")
    public ResponseMessage<JSONObject> getStatus(@RequestHeader String token) {
        JSONObject jsonObject = new JSONObject();
        boolean isValid = jwtTokenUtil.validateToken(token);
        if (isValid) {
            return new ResponseMessage(HttpStatus.OK.value(), "success", nowDeviceStatus);
        } else {
            return new ResponseMessage(HttpStatus.UNAUTHORIZED.value(), "Token is invalid", jsonObject);
        }
    }

}